# frozen_string_literal: true

module ForemanOpenbolt
  module Tasks
    def find_task_job(job_id)
      return nil if job_id.blank?
      task_job = ForemanOpenbolt::TaskJob.find_by(job_id: job_id)
      logger.debug { "find_task_job(#{job_id.inspect}) -> #{task_job.inspect}" }
      task_job
    end

    # before_action helper shared by UI and API controllers. Reads job_id
    # from params (set by the route, e.g. /jobs/:job_id/status) and 404s
    # when missing.
    def load_task_job
      job_id = params[:job_id]
      if job_id.blank?
        render_json_error('Job ID is required', :bad_request)
        return
      end
      @task_job = find_task_job(job_id)
      return if @task_job
      render_json_error("Task job #{job_id} not found", :not_found)
    end

    def task_job_status(task_job)
      {
        job_id: task_job.job_id,
        kind: 'task',
        status: task_job.status,
        submitted_at: task_job.submitted_at,
        completed_at: task_job.completed_at,
        duration: task_job.duration,
        task_name: task_job.task_name,
        task_description: task_job.task_description,
        task_parameters: task_job.task_parameters,
        targets: task_job.targets,
        smart_proxy: {
          id: task_job.smart_proxy_id,
          name: task_job.smart_proxy&.name || '(unknown)',
        },
      }
    end

    def task_job_result(task_job)
      {
        kind: 'task',
        status: task_job.status,
        command: task_job.command,
        value: task_job.result,
        log: task_job.log,
      }
    end

    def paginated_task_jobs(per_page_param:, page:)
      per_page = if per_page_param == 'all'
                   # will_paginate won't do per_page: 0
                   [::ForemanOpenbolt::TaskJob.count, 1].max
                 elsif per_page_param.present?
                   per_page_param.to_i.clamp(1, 100)
                 else
                   20
                 end
      ::ForemanOpenbolt::TaskJob.includes(:smart_proxy).recent.paginate(page: page, per_page: per_page)
    end

    # Submits a task to the smart proxy, saves the TaskJob, and schedules polling.
    # Returns the proxy-issued job id. Requires the host controller
    # to also include ForemanOpenbolt::Common for merge_encrypted_defaults
    # and scrub_options_for_storage.
    #
    # Partial launch failures (TaskJob row creation or PollTaskStatus scheduling)
    # leave the proxy job running. We do not attempt to delete proxy artifacts
    # in those branches: at that point the job is still queued or executing, so
    # the artifacts don't exist yet and the proxy has no per-job cancel hook.
    # Result files left behind on the proxy are small so we don't worry about it.
    # The priority is surfacing the failure via PartialLaunchError and, when the
    # TaskJob row exists, flipping its status to 'exception' so the error is exposed.
    def dispatch_task(smart_proxy:, openbolt_api:, task_name:, targets:, parameters:, options:)
      task_name = task_name.to_s.strip
      targets = targets.to_s.strip
      raise ForemanOpenbolt::Common::LaunchError, 'Task name and targets cannot be empty' if task_name.empty? || targets.empty?

      merged_options = merge_encrypted_defaults(options || {})

      logger.info { "Launching OpenBolt task '#{task_name}' on targets '#{targets}' via proxy #{smart_proxy.name}" }

      response = openbolt_api.launch_task(
        name: task_name,
        targets: targets,
        parameters: parameters || {},
        options: merged_options
      )
      logger.debug { "Task execution response: #{response.inspect}" }

      if response['error']
        error_detail = response['error'].is_a?(Hash) ? response['error']['message'] : response['error']
        raise ForemanOpenbolt::Common::LaunchError, "Task execution failed: #{error_detail}"
      end
      raise ForemanOpenbolt::Common::LaunchError, 'Task execution failed: No job ID returned' unless response['id']

      # Past this point the proxy is running the task. Any failure below is partial
      # state: the task is live but Foreman's record is incomplete. Raise
      # PartialLaunchError so callers don't retry and duplicate proxy-side work.
      job_id = response['id']

      task_job = begin
        # Treat task metadata as optional. ProxyAPI::Openbolt wraps transport
        # errors as ProxyException, but a metadata-fetch failure (any cause)
        # should not abort a perfectly running proxy job over a missing
        # description. Catch broadly and degrade to an empty description.
        metadata = begin
          fetched = openbolt_api.tasks[task_name]
          if fetched.nil?
            logger.warn(
              "Proxy accepted launch of '#{task_name}' (job #{job_id}) but " \
              "the task is not in the proxy's task list. Description will be empty."
            )
          end
          fetched || {}
        rescue StandardError => e
          logger.warn(
            "Could not fetch task metadata for #{task_name} after launching " \
            "job #{job_id}: #{e.class}: #{e.message}. The next poll will " \
            "likely also fail if the proxy is unreachable. Proceeding " \
            "without description."
          )
          {}
        end

        ForemanOpenbolt::TaskJob.create_from_execution!(
          proxy: smart_proxy,
          task_name: task_name,
          task_description: metadata['description'] || '',
          targets: targets.split(',').map(&:strip),
          parameters: parameters || {},
          options: scrub_options_for_storage(merged_options),
          job_id: job_id
        )
      rescue StandardError => e
        # Log the original error and backtrace via Foreman::Logging. The
        # PartialLaunchError raised below points to its own raise site, not
        # the underlying cause.
        Foreman::Logging.exception(
          "OpenBolt job #{job_id} launched on proxy #{smart_proxy.name} " \
          "but the Foreman TaskJob row could not be created",
          e
        )
        raise ForemanOpenbolt::Common::PartialLaunchError,
          "Task launched on the proxy (job #{job_id}) but Foreman could not " \
          "record it. The task will run on the proxy unmonitored. Error: #{e.message}"
      end

      begin
        ForemanTasks.async_task(Actions::ForemanOpenbolt::PollTaskStatus,
          job_id,
          smart_proxy.id)
      rescue StandardError => e
        Foreman::Logging.exception(
          "OpenBolt job #{job_id} launched on proxy #{smart_proxy.name} " \
          "but PollTaskStatus could not be scheduled",
          e
        )
        # Capture the on-disk status before update! so the log message reflects
        # what's persisted, not the in-memory assignment that just failed.
        previous_status = task_job.status
        begin
          task_job.update!(status: 'exception')
        rescue StandardError => persist_error
          # Inner rescue keeps a descriptive name so the outer `e` isn't shadowed.
          Foreman::Logging.exception(
            "Could not mark TaskJob #{job_id} as exception after polling-" \
            "schedule failure. Row will remain in '#{previous_status}' state.",
            persist_error
          )
        end
        raise ForemanOpenbolt::Common::PartialLaunchError,
          "Task launched on the proxy (job #{job_id}) but background polling " \
          "could not be scheduled. The task will run on the proxy without " \
          "status updates in Foreman. Error: #{e.message}"
      end

      job_id
    end
  end
end

# frozen_string_literal: true

require 'foreman/logging'

module ForemanOpenbolt
  module Tasks
    extend ActiveSupport::Concern
    include ForemanOpenbolt::Common

    included do
      before_action :load_smart_proxy, only: [:tasks, :reload_tasks, :task_options, :launch_task]
      before_action :load_openbolt_api, only: [:tasks, :reload_tasks, :task_options, :launch_task]
    end

    # Actions shared by the API (Api::V2::OpenboltTasksController) and UI
    # (ForemanOpenbolt::TaskController) controllers. The API controller wraps
    # each in a `super`-calling method so it can attach apipie documentation;
    # the UI controller inherits them directly.
    def tasks
      render json: @openbolt_api.tasks
    end

    def reload_tasks
      render json: @openbolt_api.reload_tasks
    end

    def task_options
      render json: openbolt_options_with_defaults
    end

    def launch_task
      job_id = dispatch_task(
        smart_proxy: @smart_proxy,
        openbolt_api: @openbolt_api,
        task_name: params[:task_name],
        targets: params[:targets],
        parameters: params[:parameters] || {},
        options: params[:options] || {}
      )
      render json: { job_id: job_id, kind: 'task' }, status: :created
    end

    # Submits a task to the smart proxy, saves the TaskJob, and schedules polling.
    # Returns the proxy-issued job id.
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

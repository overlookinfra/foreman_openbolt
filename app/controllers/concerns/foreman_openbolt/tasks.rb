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

    # Shared by the API and UI controllers. The API controller wraps each
    # action with super so it can attach apipie docs.
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

    # Submits a task to the proxy, saves the TaskJob, and schedules polling.
    # Returns the proxy-issued job id. Failures after the proxy accepts the
    # launch raise PartialLaunchError. The proxy job keeps running and there
    # is no proxy-side cancel hook right now, so we only surface the failure.
    def dispatch_task(smart_proxy:, openbolt_api:, task_name:, targets:, parameters:, options:)
      task_name = task_name.to_s.strip
      targets = targets.to_s.strip
      raise ForemanOpenbolt::Common::LaunchError, 'Task name and targets cannot be empty' if task_name.empty? || targets.empty?

      merged_options = merge_encrypted_defaults(options)

      logger.info { "Launching OpenBolt task '#{task_name}' on targets '#{targets}' via proxy #{smart_proxy.name}" }

      response = openbolt_api.launch_task(
        name: task_name,
        targets: targets,
        parameters: parameters,
        options: merged_options
      )
      logger.debug { "Task execution response: #{response.inspect}" }

      if response['error']
        error_detail = response['error'].is_a?(Hash) ? response['error']['message'] : response['error']
        raise ForemanOpenbolt::Common::LaunchError, "Task execution failed: #{error_detail}"
      end
      raise ForemanOpenbolt::Common::LaunchError, 'Task execution failed: No job ID returned' unless response['id']

      # The proxy is now running the task so any failures below are partial state.
      job_id = response['id']

      task_job = begin
        # Metadata is optional and a fetch failure should not abort a running job.
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
            "job #{job_id}: #{e.class}: #{e.message}. Proceeding without description."
          )
          {}
        end

        ForemanOpenbolt::TaskJob.create_from_execution!(
          proxy: smart_proxy,
          task_name: task_name,
          task_description: metadata['description'] || '',
          targets: targets.split(',').map(&:strip),
          parameters: parameters,
          options: scrub_options_for_storage(merged_options),
          job_id: job_id
        )
      rescue StandardError => e
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
        # Capture before update! flips the in-memory status.
        previous_status = task_job.status
        begin
          task_job.update!(status: 'exception')
        rescue StandardError => update_error
          Foreman::Logging.exception(
            "Could not mark TaskJob #{job_id} as exception after polling-" \
            "schedule failure. Row will remain in '#{previous_status}' state.",
            update_error
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

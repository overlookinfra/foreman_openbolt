# frozen_string_literal: true

# This is a Dynflow action that polls the status of an OpenBolt task job
# from the Smart Proxy. It periodically checks the job status until it is
# completed, then fetches the final results.
module Actions
  module ForemanOpenbolt
    class PollTaskStatus < Actions::EntryAction
      include Actions::RecurringAction

      POLL_INTERVAL = 5.seconds
      RETRY_LIMIT = 60 # Number of retries before giving up (5 minutes)

      # Set up the action when it is first scheduled, storing
      # IDs needed to get information from the proxy.
      def plan(job_id, proxy_id)
        plan_self(job_id: job_id, proxy_id: proxy_id)
      end

      # Main execution method that Dynflow will call repeatedly.
      # event = nil when execution starts
      # event = :poll when this is triggered by the timer
      def run(event = nil)
        if event.nil? || event.to_sym == :poll
          poll_and_reschedule
        else
          error("Received unknown event '#{event}' for OpenBolt job #{input[:job_id]}. Finishing the action.")
          finish
        end
      end

      def finalize
        Rails.logger.info("Finalized polling for OpenBolt job #{input[:job_id]}")
      end

      private

      def append_output(key, message)
        output[key] ||= []
        output[key] << message
      end

      def log(message)
        append_output(:log, "[#{Time.now.getlocal.strftime('%Y-%m-%d %H:%M:%S')}] #{message}")
      end

      def error(message)
        append_output(:error, message)
      end

      def exception(e)
        append_output(:exception, e.message)
        append_output(:exception_backtrace, e.backtrace.join("\n"))
      end

      def finish
        log("Polling finished for OpenBolt job #{input[:job_id]}")
      end

      def poll_and_reschedule
        job_id = input[:job_id]

        # If task doesn't exist or is already complete, finish
        if task_job.nil? || task_job.completed?
          finish
          return
        end

        # If the smart proxy has been deleted somehow or is unknown,
        # we can't poll for status, so finish.
        if proxy.nil?
          error("Smart Proxy with ID #{input[:proxy_id]} not found for OpenBolt job #{job_id}. Finishing the action.")
          finish
          return
        end

        begin
          api = ::ProxyAPI::Openbolt.new(url: proxy.url)

          # Fetch current status
          status_result = api.job_status(job_id: job_id)

          # Update status if changed
          if status_result && status_result['status']
            input[:retry_count] = 0
            task_job.update!(status: status_result['status'])
            log("Status: #{status_result['status']}")

            # If completed, fetch full results
            if task_job.completed?
              result = api.job_result(job_id: job_id)
              if result
                task_job.update_from_proxy_result!(result)
                log("OpenBolt job #{job_id} completed with status '#{task_job.status}'")
              else
                log("WARNING: No result returned from proxy for completed OpenBolt job #{job_id}")
              end
              finish
              return
            end
          end

          # Still running, schedule next poll in 5 seconds
          suspend do |suspended_action|
            world.clock.ping(suspended_action, POLL_INTERVAL.from_now.to_time, :poll)
          end
        rescue StandardError => e
          error("Error polling task status for job #{job_id}")
          exception(e)

          retry_count = (input[:retry_count] || 0) + 1
          input[:retry_count] = retry_count

          if retry_count > RETRY_LIMIT
            error("Could not successfully poll task status for job #{job_id} after #{retry_count} attempts. Giving up.")
            finish
            return
          end

          suspend do |suspended_action|
            world.clock.ping(suspended_action, POLL_INTERVAL.from_now.to_time, :poll)
          end
        end
      end

      def rescue_strategy
        Dynflow::Action::Rescue::Skip
      end

      def humanized_name
        _('Poll OpenBolt task execution status')
      end

      def humanized_input
        input.slice(:job_id, :proxy_id).merge(
          # Using & to handle possible nil values just in case
          proxy_name: proxy&.name,
          task_name: task_job&.task_name
        )
      end

      def task_job
        @task_job ||= ::ForemanOpenbolt::TaskJob.find_by(job_id: input[:job_id])
      end

      def proxy
        @proxy ||= ::SmartProxy.find_by(id: input[:proxy_id])
      end
    end
  end
end

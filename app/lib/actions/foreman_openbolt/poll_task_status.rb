# frozen_string_literal: true

require 'proxy_api/openbolt'

# This is a Dynflow action that polls the status of an OpenBolt task job
# from the Smart Proxy. It periodically checks the job status until it is
# completed, then fetches the final results.
module Actions
  module ForemanOpenbolt
    class PollTaskStatus < Actions::EntryAction
      POLL_INTERVAL = 5.seconds
      RETRY_LIMIT = 60 # 5 minutes at 5-second intervals

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
          log("Received unknown event '#{event}' for OpenBolt job #{input[:job_id]}", :error)
          finish
        end
      end

      def log(msg, level = :debug)
        output[:log] ||= []
        output[:log] << "[#{Time.now.getlocal.strftime('%Y-%m-%d %H:%M:%S')}] [#{level.upcase}] #{msg}"
        Rails.logger.send(level, msg)
      end

      def exception(msg, e)
        log("#{msg}: #{e.class}: #{e.message}", :error)
        log(e.backtrace.join("\n"), :error) if e.backtrace
      end

      def finish
        log("Polling finished for OpenBolt job #{input[:job_id]}")
      end

      def mark_exception!(task_job, reason)
        previous_status = task_job.status
        task_job.update!(status: 'exception')
      rescue StandardError => e
        log(
          "Could not mark TaskJob #{task_job.job_id} as exception after " \
          "#{reason}: #{e.class}: #{e.message}. Row remains " \
          "in '#{previous_status}' state and will not be re-polled.", :error
        )
        log(e.backtrace.join("\n"), :error) if e.backtrace
      end

      def completed_status?(status)
        ::ForemanOpenbolt::TaskJob::COMPLETED_STATUSES.include?(status)
      end

      def poll_and_reschedule
        job_id = input[:job_id]
        task_job = ::ForemanOpenbolt::TaskJob.find_by(job_id: job_id)

        if task_job.nil?
          log("TaskJob record not found for job #{job_id}", :error)
          finish
          return
        end

        if task_job.completed?
          finish
          return
        end

        # If the smart proxy has been deleted somehow or is unknown,
        # we can't poll for status, so finish.
        proxy = ::SmartProxy.find_by(id: input[:proxy_id])
        unless proxy
          log("Smart Proxy with ID #{input[:proxy_id]} not found for OpenBolt job #{job_id}", :error)
          mark_exception!(task_job, 'proxy not found')
          finish
          return
        end

        begin
          api = ::ProxyAPI::Openbolt.new(url: proxy.url)

          # Fetch current status. ProxyAPI::Openbolt raises ProxyReportedError
          # for a 200 + {"error": ...} result, which is handled in the rescue. Transport
          # failures raise plain ProxyException and fall through to the retry loop.
          status_result = api.job_status(job_id: job_id)

          unless status_result&.dig('status')
            log("Proxy returned response without status for job #{job_id}: #{status_result.inspect}", :error)
            mark_exception!(task_job, 'missing status in proxy response')
            finish
            return
          end

          new_status = status_result['status']

          # Fetch the result before updating the completed status. Writing
          # status first would strand the job on a transient result fetch
          # failure, since the next poll would see completed? and finish
          # resultless. retry_count is deliberately not reset here so a
          # persistently failing result endpoint still hits the retry limit.
          if completed_status?(new_status)
            result = api.job_result(job_id: job_id)

            task_job.update_from_proxy_result!(result) if result.present?
            # Fallback for a blank or statusless result body, so the row
            # never finishes stuck as running.
            task_job.update!(status: new_status) unless task_job.completed?

            if result.present?
              log("OpenBolt job #{job_id} completed with status '#{task_job.status}'", :info)
            else
              log("No result returned from proxy for completed OpenBolt job #{job_id}; recorded status '#{task_job.status}'", :error)
            end
            finish
            return
          end

          # Still running. A good status read clears the retry counter.
          input[:retry_count] = 0
          if new_status == task_job.status
            log("Poll for OpenBolt job #{job_id}: status=#{new_status}")
          else
            previous_status = task_job.status
            task_job.update!(status: new_status)
            log("OpenBolt job #{job_id} status changed from '#{previous_status}' to '#{new_status}'", :info)
          end

          suspend do |suspended_action|
            world.clock.ping(suspended_action, POLL_INTERVAL.from_now.to_time, :poll)
          end
        rescue ::ProxyAPI::Openbolt::ProxyReportedError => e
          log("Proxy reported error for job #{job_id}: #{e.message}", :error)
          mark_exception!(task_job, 'proxy-reported error')
          finish
        rescue StandardError => e
          exception("Error polling task status for job #{job_id}", e)

          retry_count = (input[:retry_count] || 0) + 1
          input[:retry_count] = retry_count

          if retry_count > RETRY_LIMIT
            log("Polling gave up for job #{job_id} after #{retry_count} attempts", :error)
            mark_exception!(task_job, "retry limit exceeded (#{retry_count} attempts)")
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
        proxy_name = ::SmartProxy.find_by(id: input[:proxy_id])&.name || '(unknown)'
        task_name = ::ForemanOpenbolt::TaskJob.find_by(job_id: input[:job_id])&.task_name
        parts = ["job #{input[:job_id]} on #{proxy_name}"]
        parts << "task: #{task_name}" if task_name
        parts.join(', ')
      end
    end
  end
end

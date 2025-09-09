# frozen_string_literal: true

module Actions
  module ForemanBolt
    class PollTaskStatus < Actions::EntryAction
      include Actions::RecurringAction

      def plan(job_id, proxy_id)
        plan_self(job_id: job_id, proxy_id: proxy_id)
      end

      def run(event = nil)
        case event
        when nil # First run
          poll_and_reschedule
        when "poll"
          poll_and_reschedule
        when "finish"
          # Task completed, nothing more to do
        end
      end

      private

      def poll_and_reschedule
        job_id = input[:job_id]
        proxy_id = input[:proxy_id]

        task_job = ::ForemanBolt::TaskJob.find_by(job_id: job_id)

        # If task doesn't exist or is already complete, finish
        if task_job.nil? || task_job.completed?
          suspend(action: "finish")
          return
        end

        begin
          proxy = ::SmartProxy.find(proxy_id)
          api = ::ProxyAPI::Bolt.new(url: proxy.url)

          # Fetch current status
          status_result = api.job_status(job_id: job_id)

          # Update status if changed
          if status_result && status_result['status']
            task_job.update!(status: status_result['status'])

            # If completed, fetch full results
            if task_job.completed?
              result = api.job_result(job_id: job_id)
              task_job.update_from_proxy_result!(result) if result
              suspend(action: "finish")
              return
            end
          end

          # Still running, schedule next poll in 5 seconds
          suspend(action: "poll") do |suspended_action|
            world.clock.ping(suspended_action, 5.seconds.from_now, "poll")
          end
        rescue StandardError => e
          Rails.logger.error("Failed to poll task status for job #{job_id}: #{e.message}")

          # On error, retry with exponential backoff (max 30 seconds)
          retry_in = [30, (input[:retry_count] || 5) * 2].min
          input[:retry_count] = retry_in

          suspend(action: "poll") do |suspended_action|
            world.clock.ping(suspended_action, retry_in.seconds.from_now, "poll")
          end
        end
      end

      def rescue_strategy
        Dynflow::Action::Rescue::Skip
      end

      def humanized_name
        _("Poll Bolt task status")
      end

      def humanized_input
        input.slice(:job_id, :proxy_id).merge(
          proxy_name: proxy_name,
          task_name: task_job&.task_name
        )
      end

      def task_job
        @task_job ||= ::ForemanBolt::TaskJob.find_by(job_id: input[:job_id])
      end

      def proxy_name
        ::SmartProxy.find_by(id: input[:proxy_id])&.name
      end
    end
  end
end

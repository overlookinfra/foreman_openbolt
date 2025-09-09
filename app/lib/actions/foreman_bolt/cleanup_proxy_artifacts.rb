# frozen_string_literal: true

module Actions
  module ForemanBolt
    class CleanupProxyArtifacts < Actions::EntryAction
      def plan(proxy_id, job_id)
        plan_self(proxy_id: proxy_id, job_id: job_id)
      end

      def run
        proxy = ::SmartProxy.find(input[:proxy_id])
        api = ::ProxyAPI::Bolt.new(url: proxy.url)

        response = api.delete_job_artifacts(job_id: input[:job_id])
        Rails.logger.info("Cleaned up artifacts for job #{input[:job_id]}: #{response}")

        Rails.logger.info("Would delete artifacts for job #{input[:job_id]} on proxy #{proxy.name}")
      rescue StandardError => e
        # Don't fail the action if cleanup fails - it's not critical
        Rails.logger.error("Failed to cleanup artifacts for job #{input[:job_id]}: #{e.message}")
      end

      def rescue_strategy
        # Skip rescue - if cleanup fails, we don't want to retry
        Dynflow::Action::Rescue::Skip
      end

      def humanized_name
        _("Cleanup Bolt task artifacts")
      end

      def humanized_input
        {
          job_id: input[:job_id],
          proxy: ::SmartProxy.find_by(id: input[:proxy_id])&.name,
        }
      end
    end
  end
end

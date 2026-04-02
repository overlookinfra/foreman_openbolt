# frozen_string_literal: true

module Actions
  module ForemanOpenbolt
    class CleanupProxyArtifacts < Actions::EntryAction
      def plan(proxy_id, job_id)
        plan_self(proxy_id: proxy_id, job_id: job_id)
      end

      def run
        proxy = ::SmartProxy.find_by(id: input[:proxy_id])
        unless proxy
          Rails.logger.warn("Proxy #{input[:proxy_id]} not found during cleanup for job #{input[:job_id]}, skipping")
          return
        end

        api = ::ProxyAPI::Openbolt.new(url: proxy.url)
        response = api.delete_job_artifacts(job_id: input[:job_id])
        Rails.logger.debug("Cleaned up artifacts for job #{input[:job_id]} on proxy #{proxy.name}: #{response}")
      rescue StandardError => e
        # Don't fail the action if cleanup fails - it's not critical
        Rails.logger.error("Failed to cleanup artifacts for job #{input[:job_id]}: #{e.class}: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n")) if e.backtrace
      end

      def rescue_strategy
        # Skip rescue - if cleanup fails, we don't want to retry
        Dynflow::Action::Rescue::Skip
      end

      def humanized_name
        _("Cleanup OpenBolt task artifacts")
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

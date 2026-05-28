# frozen_string_literal: true

module Api
  module V2
    class OpenboltJobsController < Api::V2::BaseController
      include Api::Version2
      include ForemanOpenbolt::Jobs

      resource_description do
        resource_id 'openbolt_jobs'
        api_version 'v2'
        api_base_url '/api/v2/openbolt'
      end

      def resource_class
        ForemanOpenbolt::TaskJob
      end

      api :GET, '/jobs', N_('List OpenBolt jobs recorded in Foreman')
      param_group :pagination, Api::V2::BaseController
      def jobs
        super
      end

      api :GET, '/jobs/:job_id/status', N_('Get the current status of an OpenBolt job')
      param :job_id, :identifier, required: true, desc: N_('Proxy-issued job ID returned by /launch/task')
      def job_status
        super
      end

      api :GET, '/jobs/:job_id/result',
        N_('Get the full result (command, value, log) of a completed OpenBolt job')
      param :job_id, :identifier, required: true, desc: N_('Proxy-issued job ID returned by /launch/task')
      def job_result
        super
      end
    end
  end
end

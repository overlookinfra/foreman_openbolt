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

      def_param_group :job do
        property :job_id, String, desc: N_('Proxy-issued job ID')
        property :kind, %w[task], desc: N_("Job kind. Currently always 'task', and will include 'plan' at a later date.")
        property :status, ForemanOpenbolt::TaskJob::STATUSES, desc: N_('Status of the job')
        property :submitted_at, Time, desc: N_('When the job was submitted to the proxy')
        property :completed_at, Time, allow_nil: true, desc: N_('When the job completed. Empty while the job is running.')
        property :duration, Float, allow_nil: true, desc: N_('Job duration in seconds. Empty while the job is running.')
        property :name, String, desc: N_('Name of the launched Bolt task (or later, plan)')
        property :description, String, allow_nil: true, desc: N_('Description of the launched Bolt task (or later, plan)')
        property :parameters, Hash, desc: N_('Parameters the job was launched with')
        property :targets, Array, of: String, desc: N_('Target hosts the job was launched against for tasks')
        property :smart_proxy, Hash, desc: N_('Smart proxy that executed the job') do
          property :id, Integer, desc: N_('Smart proxy ID')
          property :name, String, desc: N_('Smart proxy name')
        end
      end

      api :GET, '/jobs', N_('List of OpenBolt jobs recorded in Foreman')
      param_group :pagination, Api::V2::BaseController
      returns code: 200, desc: N_('Paginated list of jobs') do
        property :total, Integer, desc: N_('Total number of recorded jobs')
        property :page, Integer, desc: N_('Current page number')
        property :per_page, Integer, desc: N_('Number of jobs per page')
        property :results, Array, desc: N_('Job objects for the requested page') do
          param_group :job, ::Api::V2::OpenboltJobsController
        end
      end
      def jobs
        super
      end

      api :GET, '/jobs/:job_id/status', N_('Get the current status of an OpenBolt job')
      param :job_id, :identifier, required: true, desc: N_('Proxy-issued job ID returned by /launch/task')
      returns :job, code: 200, desc: N_('Current status of the job')
      def job_status
        super
      end

      api :GET, '/jobs/:job_id/result',
        N_('Get the full result (command, OpenBolt result value, log) of a completed OpenBolt job')
      param :job_id, :identifier, required: true, desc: N_('Proxy-issued job ID returned by /launch/task')
      returns code: 200, desc: N_('Full result of the job') do
        property :kind, %w[task], desc: N_("Job kind. Currently always 'task', and will include 'plan' at a later date.")
        property :status, ForemanOpenbolt::TaskJob::STATUSES, desc: N_('Status of the job')
        property :command, String, allow_nil: true,
          desc: N_('The OpenBolt command the proxy ran, with sensitive option values scrubbed. ' \
                   'Empty until the proxy reports the first status update.')
        property :value, [Hash, String], allow_nil: true,
          desc: N_('Run result as produced by the OpenBolt CLI, passed through unmodified. ' \
                   'Its layout depends on the job kind and the OpenBolt Result format. ' \
                   'On failure or exception, this may instead be a plain string holding the raw output.')
        property :log, String, allow_nil: true, desc: N_('Output log of the run')
      end
      def job_result
        super
      end
    end
  end
end

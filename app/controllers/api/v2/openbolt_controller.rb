# frozen_string_literal: true

require 'foreman/logging'
require 'proxy_api/openbolt'

module Api
  module V2
    class OpenboltController < Api::V2::BaseController
      include Api::Version2
      include ForemanOpenbolt::Jobs
      include ForemanOpenbolt::Tasks

      resource_description do
        resource_id 'openbolt'
        api_version 'v2'
        api_base_url '/api/v2/openbolt'
      end

      def resource_class
        ForemanOpenbolt::TaskJob
      end

      before_action :load_smart_proxy, only: [:tasks, :reload_tasks, :task_options, :launch_task]
      before_action :load_openbolt_api, only: [:tasks, :reload_tasks, :task_options, :launch_task]

      api :GET, '/smart_proxies/:smart_proxy_id/tasks', N_('List bolt tasks available on a smart proxy')
      param :smart_proxy_id, Integer, required: true, desc: N_('ID of the smart proxy to query')
      def tasks
        render json: @openbolt_api.tasks
      end

      api :POST, '/smart_proxies/:smart_proxy_id/tasks/reload', N_("Reload the smart proxy's bolt task cache")
      param :smart_proxy_id, Integer, required: true, desc: N_('ID of the smart proxy to reload')
      def reload_tasks
        render json: @openbolt_api.reload_tasks
      end

      api :GET, '/smart_proxies/:smart_proxy_id/tasks/options',
        N_('Get OpenBolt options metadata for a smart proxy, with Foreman setting defaults merged in')
      param :smart_proxy_id, Integer, required: true, desc: N_('ID of the smart proxy to query')
      def task_options
        render json: openbolt_options_with_defaults
      end

      api :POST, '/launch/task', N_('Launch a bolt task on a smart proxy')
      param :smart_proxy_id, Integer, required: true,
        desc: N_('ID of the smart proxy that will execute the task')
      param :task_name, String, required: true, desc: N_('Name of the bolt task to run')
      param :targets, String, required: true,
        desc: N_('Comma-separated list of target hosts the task should run on')
      param :parameters, Hash, required: false,
        desc: N_('Task-specific parameters, keyed by parameter name')
      param :options, Hash, required: false,
        desc: N_('OpenBolt options (transport, user, run-as, etc.) as accepted by the bolt CLI')
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

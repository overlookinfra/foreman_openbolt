# frozen_string_literal: true

require 'foreman/logging'
require 'proxy_api/openbolt'

module Api
  module V2
    class OpenboltTasksController < Api::V2::BaseController
      include Api::Version2
      include ForemanOpenbolt::Tasks

      resource_description do
        resource_id 'openbolt_tasks'
        api_version 'v2'
        api_base_url '/api/v2/openbolt'
      end

      api :GET, '/smart_proxies/:smart_proxy_id/tasks', N_('List bolt tasks available on a smart proxy')
      param :smart_proxy_id, Integer, required: true, desc: N_('ID of the smart proxy to query')
      def tasks
        super
      end

      api :POST, '/smart_proxies/:smart_proxy_id/tasks/reload', N_("Reload the smart proxy's bolt task cache")
      param :smart_proxy_id, Integer, required: true, desc: N_('ID of the smart proxy to reload')
      def reload_tasks
        super
      end

      api :GET, '/smart_proxies/:smart_proxy_id/tasks/options',
        N_('Get OpenBolt options metadata for a smart proxy, with Foreman setting defaults merged in')
      param :smart_proxy_id, Integer, required: true, desc: N_('ID of the smart proxy to query')
      def task_options
        super
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
        super
      end
    end
  end
end

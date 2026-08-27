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

      def_param_group :task_map do
        property :task_name, Hash, required: false,
          desc: N_('One entry per task, keyed by the task name. "task_name" is a placeholder, and the actual keys are the task names.') do
          property :description, String, desc: N_('Description from the task metadata')
          property :parameters, Hash,
            desc: N_('Parameter definitions from the task metadata, keyed by parameter name')
        end
      end

      api :GET, '/smart_proxies/:smart_proxy_id/tasks', N_('List Bolt tasks available on a smart proxy')
      param :smart_proxy_id, Integer, required: true, desc: N_('ID of the smart proxy to query')
      returns :task_map, code: 200, additional_properties: true,
        desc: N_('Hash keyed by task name. task_name below is a placeholder, and the actual keys are the task names.')
      def tasks
        super
      end

      api :POST, '/smart_proxies/:smart_proxy_id/tasks/reload', N_("Reload the smart proxy's Bolt task cache")
      param :smart_proxy_id, Integer, required: true, desc: N_('ID of the smart proxy to reload')
      returns :task_map, code: 200, additional_properties: true,
        desc: N_('The refreshed task list, in the same shape as the tasks endpoint response')
      def reload_tasks
        super
      end

      api :GET, '/smart_proxies/:smart_proxy_id/tasks/options',
        N_('Get OpenBolt options metadata for a smart proxy, with Foreman setting defaults merged in')
      param :smart_proxy_id, Integer, required: true, desc: N_('ID of the smart proxy to query')
      returns code: 200, additional_properties: true,
        desc: N_('Hash keyed by option name. "option_name" is a placeholder, and the actual keys are the option names.') do
        property :option_name, Hash, required: false, desc: N_('One entry per option, keyed by the option name') do
          property :type, [String, Array],
            desc: N_("The option's value type, either a type name or an array of the allowed values")
          property :transport, Array, of: String, desc: N_('Transports the option applies to')
          property :sensitive, [true, false], desc: N_('Whether the value is scrubbed from recorded commands and logs')
          property :description, String, desc: N_('Human readable description of the option')
          property :default, [String, Integer, TrueClass, FalseClass], required: false,
            desc: N_('Default value, from the smart proxy or a Foreman setting when one is set. ' \
                     'If a Foreman setting is present and this is a sensitive type, the default value ' \
                     'will read "[Use saved ecrypted default]".')
        end
      end
      def task_options
        super
      end

      api :POST, '/launch/task', N_('Launch a Bolt task on a smart proxy')
      param :smart_proxy_id, Integer, required: true,
        desc: N_('ID of the smart proxy that will execute the task')
      param :task_name, String, required: true, desc: N_('Name of the Bolt task to run')
      param :targets, String, required: true,
        desc: N_('Comma-separated list of target hosts the task should run on')
      param :parameters, Hash, required: false,
        desc: N_('Task-specific parameters, keyed by parameter name')
      param :options, Hash, required: false,
        desc: N_('OpenBolt options (transport, user, run-as, etc.) as accepted by the bolt CLI')
      returns code: 201, desc: N_('Job accepted by the smart proxy') do
        property :job_id, String, desc: N_('Proxy-issued job ID, usable with the /jobs/:job_id endpoints')
        property :kind, %w[task], desc: N_("Currently always 'task', and will include 'plan' at a later date.")
      end
      def launch_task
        super
      end
    end
  end
end

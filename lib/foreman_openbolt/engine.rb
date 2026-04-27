# frozen_string_literal: true

module ForemanOpenbolt
  class Engine < ::Rails::Engine
    isolate_namespace ForemanOpenbolt
    engine_name 'foreman_openbolt'

    # Add any db migrations
    initializer 'foreman_openbolt.load_app_instance_data' do |app|
      ForemanOpenbolt::Engine.paths['db/migrate'].existent.each do |path|
        app.config.paths['db/migrate'] << path
      end
    end

    initializer 'foreman_openbolt.register_plugin', before: :finisher_hook do |app|
      app.reloader.to_prepare do
        Foreman::Plugin.register :foreman_openbolt do
          requires_foreman '>= 3.17.0'
          register_gettext

          settings do
            category :openbolt, N_('OpenBolt') do
              # The setting name should be prefixed by 'openbolt_' and otherwise exactly
              # match the OpenBolt option name defined in main.rb of smart_proxy_openbolt.
              # At some point, we should figure out the best way to deduplicate this definition
              # here and in the smart proxy.
              # The proxy needs the information for validation and a custom field to tell
              # the UI which settings apply to which transports, which we can't embed here
              # easily. And the Foreman Settings UI needs these defined here on plugin load.
              # Maybe the proxy can just hold a map of settings to transports and pull the
              # settings from here. However, we'll need to figure out the best way of doing
              # Proxy -> Foreman communication with the variety of auth methods people use.

              # rubocop:disable Lint/ConstantDefinitionInBlock
              TRANSPORTS = {
                ssh: N_('SSH'),
                winrm: N_('WinRM'),
                choria: N_('Choria'),
              }.freeze
              LOG_LEVELS = {
                error: N_('Error'),
                warning: N_('Warning'),
                info: N_('Info'),
                debug: N_('Debug'),
                trace: N_('Trace'),
              }.freeze
              CHORIA_TASK_AGENTS = {
                bolt_tasks: N_('Bolt Tasks'),
                shell: N_('Shell'),
              }.freeze
              # rubocop:enable Lint/ConstantDefinitionInBlock

              # General (all transports)
              setting 'openbolt_log-level',
                type: :string,
                default: 'debug',
                full_name: N_('Log Level'),
                description: N_('Set the log level during OpenBolt execution'),
                collection: proc { LOG_LEVELS }
              setting 'openbolt_noop',
                type: :boolean,
                default: false,
                full_name: N_('No Operation'),
                description: N_(
                  'Run the OpenBolt command with the --noop flag, which will make no changes to the target host'
                )
              setting 'openbolt_password',
                type: :string,
                default: nil,
                full_name: N_('Password'),
                description: N_('Password used for SSH or WinRM authentication'),
                encrypted: true
              setting 'openbolt_tmpdir',
                type: :string,
                default: nil,
                full_name: N_('Temporary Directory'),
                description: N_('Directory to use for temporary files on target hosts during OpenBolt execution')
              setting 'openbolt_transport',
                type: :string,
                default: 'ssh',
                full_name: N_('Transport'),
                description: N_('The transport method to use for connecting to target hosts'),
                collection: proc { TRANSPORTS }
              setting 'openbolt_user',
                type: :string,
                default: nil,
                full_name: N_('User'),
                description: N_('Username used for SSH or WinRM authentication')
              setting 'openbolt_verbose',
                type: :boolean,
                default: false,
                full_name: N_('Verbose'),
                description: N_(
                  'Run the OpenBolt command with the --verbose flag. This prints additional information ' \
                  'during OpenBolt execution and will print any out::verbose plan statements.'
                )

              # Choria
              setting 'openbolt_choria-broker-timeout',
                type: :integer,
                default: nil,
                full_name: N_('Choria Broker Timeout'),
                description: N_('Time in seconds to wait when establishing a connection to a Choria broker.')
              setting 'openbolt_choria-brokers',
                type: :string,
                default: nil,
                full_name: N_('Choria Brokers'),
                description: N_(
                  'Comma-separated list of Choria broker addresses in host or host:port format ' \
                  '(e.g. broker1.example.com:4222,broker2.example.com:4222). Port defaults to 4222 if omitted. ' \
                  'When not set, the Choria client checks the config file, then SRV records, then falls back to puppet:4222.'
                )
              setting 'openbolt_choria-collective',
                type: :string,
                default: nil,
                full_name: N_('Choria Collective'),
                description: N_('Choria collective to route messages through.')
              setting 'openbolt_choria-command-timeout',
                type: :integer,
                default: nil,
                full_name: N_('Choria Command Timeout'),
                description: N_('Time in seconds to wait for command completion on target nodes.')
              setting 'openbolt_choria-config-file',
                type: :string,
                default: nil,
                full_name: N_('Choria Config File'),
                description: N_(
                  'Path on the smart proxy host to the Choria client configuration file. This file ' \
                  'must be readable by the foreman-proxy user. When not set, the proxy uses a built-in default.'
                )
              setting 'openbolt_choria-mcollective-certname',
                type: :string,
                default: nil,
                full_name: N_('Choria MCollective Certname'),
                description: N_(
                  'Override the MCollective certname for Choria client identity. When not set, the ' \
                  'proxy derives this automatically from its SSL certificate.'
                )
              setting 'openbolt_choria-puppet-environment',
                type: :string,
                default: nil,
                full_name: N_('Choria Puppet Environment'),
                description: N_(
                  'Puppet environment used by the Choria bolt_tasks agent to locate task files. ' \
                  "Only applies when the Choria Task Agent is 'bolt_tasks'. Defaults to " \
                  "'production' when not specified."
                )
              setting 'openbolt_choria-rpc-timeout',
                type: :integer,
                default: nil,
                full_name: N_('Choria RPC Timeout'),
                description: N_('Time in seconds to wait for RPC responses from target nodes.')
              setting 'openbolt_choria-ssl-ca',
                type: :string,
                default: nil,
                full_name: N_('Choria SSL CA'),
                description: N_(
                  'Path on the smart proxy host to the Choria CA certificate. This file must be ' \
                  'readable by the foreman-proxy user.'
                )
              setting 'openbolt_choria-ssl-cert',
                type: :string,
                default: nil,
                full_name: N_('Choria SSL Certificate'),
                description: N_(
                  'Path on the smart proxy host to the Choria client SSL certificate. This file ' \
                  'must be readable by the foreman-proxy user.'
                )
              setting 'openbolt_choria-ssl-key',
                type: :string,
                default: nil,
                full_name: N_('Choria SSL Key'),
                description: N_(
                  'Path on the smart proxy host to the Choria client SSL private key. This file ' \
                  'must be readable by the foreman-proxy user.'
                )
              setting 'openbolt_choria-task-agent',
                type: :string,
                default: 'bolt_tasks',
                full_name: N_('Choria Task Agent'),
                description: N_(
                  'Choria agent used to execute tasks on target nodes. Use the bolt_tasks agent for ' \
                  'standard OpenBolt tasks, or the shell agent to run shell commands.'
                ),
                collection: proc { CHORIA_TASK_AGENTS }
              setting 'openbolt_choria-task-timeout',
                type: :integer,
                default: nil,
                full_name: N_('Choria Task Timeout'),
                description: N_('Time in seconds to wait for task completion on target nodes.')

              # SSH
              setting 'openbolt_host-key-check',
                type: :boolean,
                default: true,
                full_name: N_('SSH Host Key Check'),
                description: N_('Whether to perform host key verification when connecting to targets over SSH')
              setting 'openbolt_private-key',
                type: :string,
                default: nil,
                full_name: N_('SSH Private Key'),
                description: N_(
                  'Path on the smart proxy host to the private key used for SSH authentication. This key must be ' \
                  'readable by the foreman-proxy user.'
                )
              setting 'openbolt_run-as',
                type: :string,
                default: nil,
                full_name: N_('SSH Run As User'),
                description: N_(
                  'The user to run commands as on the target host. This requires that the user specified ' \
                  'in the "user" option has permission to run commands as this user.'
                )
              setting 'openbolt_sudo-password',
                type: :string,
                default: nil,
                full_name: N_('SSH Sudo Password'),
                description: N_('Password used for privilege escalation when using SSH'),
                encrypted: true

              # WinRM
              setting 'openbolt_ssl',
                type: :boolean,
                default: true,
                full_name: N_('WinRM SSL'),
                description: N_('Use SSL when connecting to hosts via WinRM')
              setting 'openbolt_ssl-verify',
                type: :boolean,
                default: true,
                full_name: N_('WinRM SSL Verify'),
                description: N_('Verify remote host SSL certificate when connecting to hosts via WinRM')
            end
          end

          # Right now, this is really only pulling in routes. But leaving
          # it as a general global JS file for future expansion.
          register_global_js_file 'global'

          security_block :foreman_openbolt do
            permission :execute_openbolt,
              { :'foreman_openbolt/task' => [
                :page_launch_task, :page_task_execution, :page_task_history,
                :fetch_tasks, :reload_tasks, :fetch_openbolt_options,
                :launch_task, :job_status, :job_result, :fetch_task_history, :show
              ] }
            permission :view_smart_proxies_openbolt, :smart_proxies => [:index, :show], :resource_type => 'SmartProxy'
          end

          role 'OpenBolt Executor', [:execute_openbolt]
          add_all_permissions_to_default_roles

          sub_menu :top_menu, :openbolt,
            icon: 'fa fa-bolt',
            caption: N_('OpenBolt'),
            after: :hosts_menu do
            menu :top_menu, :page_launch_task,
              caption: N_('Launch Task'),
              engine: ForemanOpenbolt::Engine
            menu :top_menu, :page_task_history,
              caption: N_('Task History'),
              engine: ForemanOpenbolt::Engine
          end
        end
      end
    end

    rake_tasks do
      Rake::Task['db:seed'].enhance do
        ForemanOpenbolt::Engine.load_seed
      end
    end
  end
end

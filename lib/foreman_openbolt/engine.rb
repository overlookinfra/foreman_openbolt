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
          requires_foreman '>= 3.14.0'
          register_gettext

          settings do
            category :openbolt, N_('OpenBolt') do
              # The setting name should exactly match the OpenBolt option name defined
              # in main.rb of smart_proxy_openbolt. At some point, we should figure out the
              # best way to deduplicate this definition here and in the smart proxy.
              # The proxy needs the information for validation and a custom field to tell
              # the UI which settings apply to which transports, which we can't embed here
              # easily. And the Foreman Settings UI needs these defined here on plugin load.
              # Maybe the proxy can just hold a map of settings to transports and pull the
              # settings from here. However, we'll need to figure out the best way of doing
              # Proxy -> Foreman communication with the variety of auth methods people use.
              TRANSPORTS = { 'ssh': N_('SSH'), 'winrm': N_('WinRM') }
              LOG_LEVELS = {
                'error': N_('Error'),
                'warning': N_('Warning'),
                'info': N_('Info'),
                'debug': N_('Debug'),
                'trace': N_('Trace')
              }
              setting 'transport',
                type: :string,
                default: 'ssh',
                full_name: N_('Transport'),
                description: N_('The transport method to use for connecting to target hosts'),
                collection: proc { TRANSPORTS }
              setting 'log-level',
                type: :string,
                default: 'debug',
                full_name: N_('Log Level'),
                description: N_('Set the log level during OpenBolt execution'),
                collection: proc { LOG_LEVELS }
              setting 'verbose',
                type: :boolean,
                default: false,
                full_name: N_('Verbose'),
                description: N_('Run the OpenBolt command with the --verbose flag. This prints additional information during OpenBolt execution and will print any out::verbose plan statements.')
              setting 'noop',
                type: :boolean,
                default: false,
                full_name: N_('No Operation'),
                description: N_('Run the OpenBolt command with the --noop flag, which will make no changes to the target host')
              setting 'tmpdir',
                type: :string,
                default: '',
                full_name: N_('Temporary Directory'),
                description: N_('Directory to use for temporary files on target hosts during OpenBolt execution')
              setting 'user',
                type: :string,
                default: '',
                full_name: N_('User'),
                description: N_('Username used for SSH or WinRM authentication')
              setting 'password',
                type: :string,
                default: '',
                full_name: N_('Password'),
                description: N_('Password used for SSH or WinRM authentication'),
                encrypted: true
              setting 'host-key-check',
                type: :boolean,
                default: true,
                full_name: N_('SSH Host Key Check'),
                description: N_('Do host key checking when connecting to hosts via SSH')
              setting 'private-key',
                type: :string,
                default: '',
                full_name: N_('SSH Private Key'),
                description: N_('Path on the smart proxy host to the private key used for SSH authentication. This key must be readable by the foreman-proxy user.')
              setting 'run-as',
                type: :string,
                default: '',
                full_name: N_('SSH Run As User'),
                description: N_('User to run as via privilege escalation when using SSH transport')
              setting 'sudo-password',
                type: :string,
                default: '',
                full_name: N_('SSH Sudo Password'),
                description: N_('Password for the user to run commands as via sudo'),
                encrypted: true
              setting 'ssl',
                type: :boolean,
                default: true,
                full_name: N_('WinRM SSL'),
                description: N_('Use SSL when connecting to hosts')
              setting 'ssl-verify',
                type: :boolean,
                default: true,
                full_name: N_('WinRM SSL Verify'),
                description: N_('Verify remote host SSL certificate when connecting to hosts')
            end
          end

          # Right now, this is really only pulling in routes. But leaving
          # it as a general global JS file for future expansion.
          register_global_js_file 'global'

          security_block :foreman_openbolt do
            permission :execute_openbolt,
              { :'foreman_openbolt/task' => [
                :page_launch_task, :page_task_execution, :page_task_history,
                :fetch_smart_proxies, :fetch_tasks, :reload_tasks, :fetch_openbolt_options,
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

# frozen_string_literal: true

module ForemanBolt
  class Engine < ::Rails::Engine
    isolate_namespace ForemanBolt
    engine_name 'foreman_bolt'

    # Add any db migrations
    initializer 'foreman_bolt.load_app_instance_data' do |app|
      ForemanBolt::Engine.paths['db/migrate'].existent.each do |path|
        app.config.paths['db/migrate'] << path
      end
    end

    initializer 'foreman_bolt.register_plugin', before: :finisher_hook do |app|
      app.reloader.to_prepare do
        Foreman::Plugin.register :foreman_bolt do
          requires_foreman '>= 3.14.0'
          register_gettext

          # Right now, this is really only pulling in routes. But leaving
          # it as a general global JS file for future expansion.
          register_global_js_file 'global'

          security_block :foreman_bolt do
            permission :execute_bolt,
              { :'foreman_bolt/task' => [
                :new_task, :task_exec, :fetch_smart_proxies,
                :fetch_tasks, :reload_tasks, :fetch_bolt_options,
                :execute_task, :job_status, :job_result
              ],
                :hosts => [:index, :auto_complete_search],
                :hostgroups => [:index] }
            permission :view_smart_proxies_bolt, :smart_proxies => [:index, :show], :resource_type => 'SmartProxy'
          end

          role 'Bolt Executor', [:execute_bolt]
          add_all_permissions_to_default_roles

          sub_menu :top_menu, :bolt,
            icon: 'fa fa-bolt',
            caption: N_('Bolt'),
            after: :hosts_menu do
            menu :top_menu, :new_task,
              caption: N_('Run Task'),
              engine: ForemanBolt::Engine
          end
        end
      end
    end

    rake_tasks do
      Rake::Task['db:seed'].enhance do
        ForemanBolt::Engine.load_seed
      end
    end
  end
end

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

    initializer 'foreman_bolt.register_plugin', :before => :finisher_hook do |app|
      app.reloader.to_prepare do
        Foreman::Plugin.register :foreman_bolt do
          requires_foreman '>= 3.14.0'
          register_gettext

          # Add permissions
          security_block :foreman_bolt do
            permission :view_foreman_bolt, { :'foreman_bolt/new_task' => [:new_task, :task_exec] }
            permission :execute_foreman_bolt_tasks, { :'foreman_bolt/task' => [:task_exec] }
          end

          # Specific ForemanBolt role
          role 'ForemanBolt', [:view_foreman_bolt, :execute_foreman_bolt_tasks]

          # add menu entry
          sub_menu :top_menu, :bolt, icon: 'pficon pficon-enterprise', caption: N_('Bolt'), after: :hosts_menu do
            menu :top_menu, :new_task, caption: N_('Run Task'), engine: ForemanBolt::Engine
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

ForemanBolt::Engine.routes.draw do
  # Form page to run a task
  get 'new_task', to: 'task#new_task'

  # JS endpoints for populating the new_task page
  get 'fetch_tasks', to: 'task#fetch_tasks'
  get 'reload_tasks', to: 'task#reload_tasks'
  get 'fetch_bolt_options', to: 'task#fetch_bolt_options'

  # Submit task execution
  post 'task_exec', to: 'task#task_exec'
end

Foreman::Application.routes.draw do
  mount ForemanBolt::Engine, at: '/foreman_bolt'
end

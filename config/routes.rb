ForemanBolt::Engine.routes.draw do
  get 'run_task', to: 'task#render_run_task'
  get 'get_tasks', to: 'task#get_tasks'
  get 'reload_tasks', to: 'task#reload_tasks'
  post 'task_exec', to: 'task#task_exec'
end

Foreman::Application.routes.draw do
  mount ForemanBolt::Engine, at: '/foreman_bolt'
end

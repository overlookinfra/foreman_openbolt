ForemanBolt::Engine.routes.draw do
  get 'run_task', to: 'task#render_run_task', as: 'run_task'
  get 'get_tasks', to: 'task#get_tasks', as: 'get_tasks'
  post 'task_exec', to: 'task#task_exec', as: 'task_exec'
  get 'get_tasks', to: 'task#get_tasks'
end

Foreman::Application.routes.draw do
  mount ForemanBolt::Engine, at: '/foreman_bolt'
end

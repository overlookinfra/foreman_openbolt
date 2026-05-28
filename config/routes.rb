# frozen_string_literal: true

ForemanOpenbolt::Engine.routes.draw do
  # React-rendered pages
  get 'page_launch_task', to: 'task#page_launch_task', as: :page_launch_task
  get 'page_task_execution', to: 'task#page_task_execution', as: :page_task_execution
  get 'page_task_history', to: 'task#page_task_history', as: :page_task_history

  # API endpoints
  get 'fetch_tasks', to: 'task#tasks'
  post 'reload_tasks', to: 'task#reload_tasks'
  get 'fetch_openbolt_options', to: 'task#task_options'
  post 'launch_task', to: 'task#launch_task'
  get 'job_status', to: 'task#job_status'
  get 'job_result', to: 'task#job_result'

  # Task job management endpoints
  get 'fetch_task_history', to: 'task#jobs'
end

Foreman::Application.routes.draw do
  mount ForemanOpenbolt::Engine, at: '/foreman_openbolt'

  namespace :api, defaults: { format: 'json' } do
    scope '(:apiv)',
      module: :v2,
      defaults: { apiv: 'v2' },
      apiv: /v1|v2/,
      constraints: ApiConstraints.new(version: 2, default: true) do
      scope '/openbolt', as: 'openbolt' do
        # Proxy-scoped task operations
        resources :smart_proxies, only: [] do
          resources :tasks, only: [], controller: 'openbolt_tasks' do
            collection do
              get  '/',      action: :tasks
              post :reload,  action: :reload_tasks
              get  :options, action: :task_options
            end
          end
        end

        # Launch is kind-specific (future: POST 'launch/plan').
        post 'launch/task', to: 'openbolt_tasks#launch_task', as: 'launch_task'

        # Job queries are kind-agnostic. Reads come from the Foreman DB, populated by PollTaskStatus.
        resources :jobs, only: [], controller: 'openbolt_jobs', param: :job_id do
          collection do
            get '/', action: :jobs
          end
          member do
            get :status, action: :job_status
            get :result, action: :job_result
          end
        end
      end
    end
  end
end

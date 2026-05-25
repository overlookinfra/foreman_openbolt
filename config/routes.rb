# frozen_string_literal: true

ForemanOpenbolt::Engine.routes.draw do
  # React-rendered pages
  get 'page_launch_task', to: 'task#page_launch_task', as: :page_launch_task
  get 'page_task_execution', to: 'task#page_task_execution', as: :page_task_execution
  get 'page_task_history', to: 'task#page_task_history', as: :page_task_history

  # API endpoints
  get 'fetch_tasks', to: 'task#fetch_tasks'
  get 'reload_tasks', to: 'task#reload_tasks'
  get 'fetch_openbolt_options', to: 'task#fetch_openbolt_options'
  post 'launch_task', to: 'task#launch_task'
  get 'job_status', to: 'task#job_status'
  get 'job_result', to: 'task#job_result'

  # Task job management endpoints
  get 'fetch_task_history', to: 'task#fetch_task_history'
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
        get  'smart_proxies/:smart_proxy_id/tasks',         to: 'openbolt#tasks',          as: 'smart_proxy_tasks'
        post 'smart_proxies/:smart_proxy_id/tasks/reload',  to: 'openbolt#reload_tasks',   as: 'smart_proxy_reload_tasks'
        get  'smart_proxies/:smart_proxy_id/tasks/options', to: 'openbolt#task_options',   as: 'smart_proxy_task_options'

        # Launch is kind-specific (future: POST 'launch/plan').
        post 'launch/task', to: 'openbolt#launch_task', as: 'launch_task'

        # Job queries are kind-agnostic. Reads come from the Foreman DB, populated by PollTaskStatus.
        get 'jobs',                to: 'openbolt#jobs',       as: 'jobs'
        get 'jobs/:job_id/status', to: 'openbolt#job_status', as: 'job_status'
        get 'jobs/:job_id/result', to: 'openbolt#job_result', as: 'job_result'
      end
    end
  end
end

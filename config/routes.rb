# frozen_string_literal: true

ForemanBolt::Engine.routes.draw do
  # React-rendered pages
  get 'new_task', to: 'task#new_task', as: :new_task
  get 'task_exec', to: 'task#task_exec', as: :task_exec
  get 'task_jobs', to: 'task#task_jobs', as: :task_jobs

  # API endpoints
  get 'fetch_tasks', to: 'task#fetch_tasks'
  get 'reload_tasks', to: 'task#reload_tasks'
  get 'fetch_bolt_options', to: 'task#fetch_bolt_options'
  post 'execute_task', to: 'task#execute_task'
  get 'job_status', to: 'task#job_status'
  get 'job_result', to: 'task#job_result'

  # Task job management endpoints
  get 'fetch_task_jobs', to: 'task#fetch_task_jobs'
  get 'fetch_task_jobs/:id', to: 'task#show', as: :task_job
end

Foreman::Application.routes.draw do
  mount ForemanBolt::Engine, at: '/foreman_bolt'
end

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
  get 'fetch_task_history/:id', to: 'task#show', as: :task_job
end

Foreman::Application.routes.draw do
  mount ForemanOpenbolt::Engine, at: '/foreman_openbolt'
end

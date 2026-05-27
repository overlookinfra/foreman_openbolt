# frozen_string_literal: true

require 'foreman/logging'
require 'foreman_openbolt/engine'
require 'proxy_api/openbolt'

module ForemanOpenbolt
  class TaskController < ApplicationController
    include ForemanOpenbolt::Tasks

    before_action :load_smart_proxy, only: [:tasks, :reload_tasks, :task_options, :launch_task]
    before_action :load_openbolt_api, only: [:tasks, :reload_tasks, :task_options, :launch_task]
    before_action :load_task_job, only: [:job_status, :job_result]

    rescue_from StandardError do |error|
      Foreman::Logging.exception('OpenBolt UI unexpected error', error)
      render_json_error("Internal server error: #{error.message}", :internal_server_error)
    end

    # React-rendered pages
    def page_launch_task
      render 'foreman_openbolt/react_page'
    end

    def page_task_execution
      render 'foreman_openbolt/react_page'
    end

    def page_task_history
      render 'foreman_openbolt/react_page'
    end

    def tasks
      render json: @openbolt_api.tasks
    end

    def reload_tasks
      render json: @openbolt_api.reload_tasks
    end

    def task_options
      render json: openbolt_options_with_defaults
    end

    def launch_task
      job_id = dispatch_task(
        smart_proxy: @smart_proxy,
        openbolt_api: @openbolt_api,
        task_name: params[:task_name],
        targets: params[:targets],
        parameters: params[:parameters] || {},
        options: params[:options] || {}
      )
      render json: { job_id: job_id, kind: 'task' }, status: :created
    end

    def job_status
      render json: task_job_status(@task_job)
    end

    def job_result
      render json: task_job_result(@task_job)
    end

    def jobs
      paginated = paginated_task_jobs(per_page_param: params[:per_page], page: params[:page])

      render json: {
        total: paginated.total_entries,
        page: paginated.current_page,
        per_page: paginated.per_page,
        results: paginated.map { |job| task_job_status(job) },
      }
    end
  end
end

# frozen_string_literal: true

require 'foreman/logging'
require 'foreman_openbolt/engine'
require 'proxy_api/openbolt'

module ForemanOpenbolt
  class TaskController < ApplicationController
    include ForemanOpenbolt::Common
    include ForemanOpenbolt::Tasks

    before_action :load_smart_proxy, only: [
      :fetch_tasks, :reload_tasks, :fetch_openbolt_options, :launch_task
    ]
    before_action :load_openbolt_api, only: [
      :fetch_tasks, :reload_tasks, :fetch_openbolt_options, :launch_task
    ]
    before_action :load_task_job, only: [:job_status, :job_result]

    rescue_from StandardError do |error|
      Foreman::Logging.exception('OpenBolt UI unexpected error', error)
      render_json_error("Internal server error: #{error.message}", :internal_server_error)
    end

    rescue_from ForemanOpenbolt::Common::LaunchError do |error|
      logger.warn("OpenBolt UI launch failed: #{error.class}: #{error.message}")
      render_json_error(error.message, :bad_request)
    end

    rescue_from ForemanOpenbolt::Common::PartialLaunchError do |error|
      Foreman::Logging.exception("OpenBolt UI partial launch failure: #{error.message}", error)
      render_json_error(error.message, :internal_server_error)
    end

    rescue_from ProxyAPI::ProxyException do |error|
      Foreman::Logging.exception('OpenBolt UI proxy call failed', error)
      render_json_error("Smart Proxy error: #{error.message}", :bad_gateway)
    end

    rescue_from ForemanOpenbolt::Common::MissingEncryptedDefault do |error|
      logger.warn("OpenBolt UI missing encrypted default failure: #{error.message}")
      render_json_error(error.message, :bad_request)
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

    def fetch_tasks
      render json: @openbolt_api.tasks
    end

    def reload_tasks
      render json: @openbolt_api.reload_tasks
    end

    def fetch_openbolt_options
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

    def fetch_task_history
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

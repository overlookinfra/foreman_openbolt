# frozen_string_literal: true

require 'foreman_openbolt/engine'
require 'proxy_api/openbolt'

module ForemanOpenbolt
  class TaskController < ::ApplicationController
    include ForemanOpenbolt::Common
    include ForemanOpenbolt::Tasks

    before_action :load_smart_proxy, only: [
      :fetch_tasks, :reload_tasks, :fetch_openbolt_options, :launch_task
    ]
    before_action :load_openbolt_api, only: [
      :fetch_tasks, :reload_tasks, :fetch_openbolt_options, :launch_task
    ]
    before_action :load_task_job, only: [:job_status, :job_result]

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
      render_openbolt_api_call(:tasks)
    end

    def reload_tasks
      render_openbolt_api_call(:reload_tasks)
    end

    def fetch_openbolt_options
      render json: openbolt_options_with_defaults
    rescue ProxyAPI::ProxyException => e
      log_exception('fetch_openbolt_options', e)
      render_json_error("Smart Proxy error: #{e.message}", :bad_gateway)
    rescue StandardError => e
      log_exception('fetch_openbolt_options', e)
      render_json_error("Internal server error: #{e.message}", :internal_server_error)
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
      render json: { job_id: job_id }
    rescue ForemanOpenbolt::Common::LaunchError,
           ForemanOpenbolt::Common::MissingEncryptedDefault => e
      log_exception('launch_task', e)
      render_json_error(e.message, :bad_request)
    rescue ForemanOpenbolt::Common::PartialLaunchError => e
      log_exception('launch_task', e)
      render_json_error(e.message, :internal_server_error)
    rescue ProxyAPI::ProxyException => e
      log_exception('launch_task', e)
      render_json_error("Smart Proxy error: #{e.message}", :bad_gateway)
    rescue StandardError => e
      log_exception('launch_task', e)
      render_json_error("Error launching task: #{e.message}", :internal_server_error)
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
        results: paginated.map { |job| task_job_status(job) },
        total: paginated.total_entries,
        page: paginated.current_page,
        per_page: paginated.per_page,
      }
    rescue StandardError => e
      log_exception('fetch_task_history', e)
      render_json_error("Error loading task history: #{e.message}", :internal_server_error)
    end

    def render_openbolt_api_call(method_name, **args)
      result = @openbolt_api.send(method_name, **args)
      logger.debug("OpenBolt API call #{method_name} successful for proxy #{@smart_proxy.name}")
      render json: result
    rescue ProxyAPI::ProxyException => e
      log_exception(method_name, e)
      render_json_error("Smart Proxy error: #{e.message}", :bad_gateway)
    rescue StandardError => e
      log_exception(method_name, e)
      render_json_error("Internal server error: #{e.message}", :internal_server_error)
    end
  end
end

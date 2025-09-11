# frozen_string_literal: true

require 'foreman_openbolt/engine'
require 'proxy_api/openbolt'

module ForemanOpenbolt
  class TaskController < ::ApplicationController
    include ::Foreman::Controller::AutoCompleteSearch

    before_action :load_smart_proxy, only: [
      :fetch_tasks, :reload_tasks, :fetch_openbolt_options, :execute_task, :job_status, :job_result
    ]
    before_action :load_openbolt_api, only: [
      :fetch_tasks, :reload_tasks, :fetch_openbolt_options, :execute_task, :job_status, :job_result
    ]
    before_action :load_task_job, only: [:job_status, :job_result]

    # React-rendered pages
    def new_task
      render 'foreman_openbolt/react_page'
    end

    def task_exec
      render 'foreman_openbolt/react_page'
    end

    def task_history
      render 'foreman_openbolt/react_page'
    end

    def fetch_tasks
      render_openbolt_api_call(:tasks)
    end

    def reload_tasks
      render_openbolt_api_call(:reload_tasks)
    end

    def fetch_openbolt_options
      render_openbolt_api_call(:openbolt_options)
    end

    def execute_task
      required_args = [:task_name, :targets]
      missing_args = required_args.select { |arg| params[arg].blank? }

      if missing_args.any?
        return render_error("Missing required arguments to the execute_task function: #{missing_args.join(', ')}",
          :bad_request)
      end

      begin
        task_name = params[:task_name].to_s.strip
        targets = params[:targets].to_s.strip
        task_params = params[:params] || {}
        options = params[:options] || {}

        return render_error('Task name and targets cannot be empty', :bad_request) if task_name.empty? || targets.empty?

        logger.info("Executing OpenBolt task '#{task_name}' on targets '#{targets}' via proxy #{@smart_proxy.name}")

        response = @openbolt_api.run_task(
          name: task_name,
          targets: targets,
          parameters: task_params,
          options: options
        )

        logger.info("Task execution response: #{response.inspect}")

        return render_error("Task execution failed: #{response['error']}", :bad_request) if response['error']
        return render_error('Task execution failed: No job ID returned', :bad_request) unless response['id']

        task_job = TaskJob.create_from_execution!(
          proxy: @smart_proxy,
          task_name: task_name,
          targets: targets.split(',').map(&:strip),
          parameters: task_params,
          options: options,
          job_id: response['id']
        )

        # Start background polling to update status
        ForemanTasks.async_task(Actions::ForemanOpenbolt::PollTaskStatus,
          response['id'],
          @smart_proxy.id)

        render json: {
          job_id: response['id'],
          proxy_id: @smart_proxy.id,
          proxy_name: @smart_proxy.name,
        }
      rescue ActiveRecord::RecordInvalid => e
        logger.error("Failed to create TaskRun: #{e.message}")
        render_error("Database error: #{e.message}", :internal_server_error)
      rescue StandardError => e
        logger.error("Task execution error: #{e.class}: #{e.message}")
        logger.error("Backtrace: #{e.backtrace.first(5).join("\n")}")
        render_error("Error executing task: #{e.message}", :internal_server_error)
      end
    end

    def job_status
      return render_error('Task job not found', :not_found) unless @task_job

      # Try to update from proxy, but don't fail if proxy is down
      begin
        proxy_status = @openbolt_api.job_status(job_id: @task_job.job_id)
        if proxy_status && proxy_status['status'] && proxy_status['status'] != @task_job.status
          @task_job.update!(status: proxy_status['status'])
        end
      rescue ProxyAPI::ProxyException => e
        logger.warn("Could not fetch status from proxy: #{e.message}")
      end

      render json: {
        status: @task_job.status,
        submitted_at: @task_job.submitted_at,
        completed_at: @task_job.completed_at,
        duration: @task_job.duration,
      }
    end

    def job_result
      return render_error('Task job not found', :not_found) unless @task_job

      # If we don't have the result cached and task is complete, fetch from proxy
      if @task_job.result.nil? && @task_job.completed?
        begin
          proxy_result = @openbolt_api.job_result(job_id: @task_job.job_id)
          @task_job.update_from_proxy_result!(proxy_result) if proxy_result
        rescue ProxyAPI::ProxyException => e
          logger.warn("Could not fetch result from proxy: #{e.message}")
        end
      end

      # Return the actual task results
      render json: {
        status: @task_job.status,
        value: @task_job.result,
        log: @task_job.log,
      }
    end

    # List of all task history
    def fetch_task_history
      @task_history = TaskJob.includes(:smart_proxy)
                          .recent
                          .paginate(page: params[:page], per_page: params[:per_page] || 20)

      render json: {
        results: @task_history.map { |job| serialize_task_job(job) },
        total: @task_history.total_entries,
        page: @task_history.current_page,
        per_page: @task_history.limit_value,
      }
    end

    # Show a specific task job
    def show
      task_job = TaskJob.find(params[:id])
      render json: serialize_task_job(task_job, detailed: true)
    rescue ActiveRecord::RecordNotFound
      render_error('Task job not found', :not_found)
    end

    private

    def load_smart_proxy
      proxy_id = params[:proxy_id]
      if proxy_id.blank?
        render_error('Smart Proxy ID is required', :bad_request)
        return false
      end

      return true if @smart_proxy && @smart_proxy.id.to_s == proxy_id.to_s

      @smart_proxy = SmartProxy.authorized(:view_smart_proxies).find_by(id: proxy_id)

      unless @smart_proxy
        render_error("Smart Proxy with ID #{proxy_id} not found or not authorized", :not_found)
        return false
      end

      true
    end

    def load_openbolt_api
      return false unless @smart_proxy
      return true if @openbolt_api && @openbolt_api.url == @smart_proxy.url

      begin
        @openbolt_api = ProxyAPI::Openbolt.new(url: @smart_proxy.url)
      rescue StandardError => e
        logger.error("Failed to initialize OpenBolt API for proxy #{@smart_proxy.name}: #{e.message}")
        render_error("Failed to connect to Smart Proxy", :bad_gateway)
        return false
      end

      true
    end

    def load_task_job
      job_id = params[:job_id]
      logger.debug("load_task_job - Job ID: #{job_id}")

      if job_id.present?
        @task_job = TaskJob.find_by(job_id: job_id)
        logger.debug("load_task_job - Task Job: #{@task_job.inspect}")
      end
    end

    def render_openbolt_api_call(method_name, **args)
      result = @openbolt_api.send(method_name, **args)
      logger.debug("OpenBolt API call #{method_name} successful for proxy #{@smart_proxy.name}")
      render json: result
    rescue ProxyAPI::ProxyException => e
      logger.error("OpenBolt API error for #{method_name}: #{e.message}")
      render_error("Smart Proxy error: #{e.message}", :bad_gateway)
    rescue StandardError => e
      logger.error("Unexpected error in #{method_name}: #{e.class}: #{e.message}")
      render_error("Internal server error: #{e.message}", :internal_server_error)
    end

    def render_error(message, status)
      render json: { error: message }, status: status
    end

    def serialize_task_job(task_job, detailed: false)
      data = {
        job_id: task_job.job_id,
        task_name: task_job.task_name,
        status: task_job.status,
        target_count: task_job.target_count,
        smart_proxy: {
          id: task_job.smart_proxy_id,
          name: task_job.smart_proxy.name,
        },
        submitted_at: task_job.submitted_at,
        completed_at: task_job.completed_at,
        duration: task_job.duration,
      }

      if detailed
        data.merge!(
          targets: task_job.targets,
          task_parameters: task_job.task_parameters,
          openbolt_options: task_job.openbolt_options,
          result: task_job.result,
          log: task_job.log
        )
      end

      data
    end
  end
end

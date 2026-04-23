# frozen_string_literal: true

require 'foreman_openbolt/engine'
require 'proxy_api/openbolt'

module ForemanOpenbolt
  class TaskController < ::ApplicationController
    include ::Foreman::Controller::AutoCompleteSearch

    # For passing to/from the UI
    ENCRYPTED_PLACEHOLDER = '[Use saved encrypted default]'
    # For saving to the database
    REDACTED_PLACEHOLDER = '*****'

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
      options = @openbolt_api.openbolt_options

      # Get defaults from Foreman settings.
      # For encrypted settings, show the placeholder only if a non-empty value
      # has been saved, so the UI shows an empty field for unconfigured passwords
      # instead of a misleading placeholder.
      defaults = {}
      openbolt_settings.each do |setting|
        key = setting.name.sub(/^openbolt_/, '')
        if setting.encrypted?
          defaults[key] = ENCRYPTED_PLACEHOLDER unless setting.value.to_s.empty?
        elsif !setting.value.to_s.empty?
          defaults[key] = setting.value
        end
      end

      # Merge the defaults into the options metadata
      result = {}
      options.each do |name, meta|
        result[name] = meta.dup
        result[name]['default'] = defaults[name] if defaults.key?(name)
      end

      render json: result
    rescue ProxyAPI::ProxyException => e
      log_exception('fetch_openbolt_options', e)
      render_error("Smart Proxy error: #{e.message}", :bad_gateway)
    rescue StandardError => e
      log_exception('fetch_openbolt_options', e)
      render_error("Internal server error: #{e.message}", :internal_server_error)
    end

    def launch_task
      required_args = [:task_name, :targets]
      missing_args = required_args.select { |arg| params[arg].blank? }

      if missing_args.any?
        return render_error("Missing required arguments to the launch_task function: #{missing_args.join(', ')}",
          :bad_request)
      end

      begin
        task_name = params[:task_name].to_s.strip
        targets = params[:targets].to_s.strip
        task_params = params[:params] || {}
        options = params[:options] || {}
        options = merge_encrypted_defaults(options)

        return render_error('Task name and targets cannot be empty', :bad_request) if task_name.empty? || targets.empty?

        logger.info("Launching OpenBolt task '#{task_name}' on targets '#{targets}' via proxy #{@smart_proxy.name}")

        response = @openbolt_api.launch_task(
          name: task_name,
          targets: targets,
          parameters: task_params,
          options: options
        )

        logger.debug("Task execution response: #{response.inspect}")

        if response['error']
          error_detail = response['error'].is_a?(Hash) ? response['error']['message'] : response['error']
          return render_error("Task execution failed: #{error_detail}", :bad_request)
        end
        return render_error('Task execution failed: No job ID returned', :bad_request) unless response['id']

        metadata = @openbolt_api.tasks[task_name] || {}
        TaskJob.create_from_execution!(
          proxy: @smart_proxy,
          task_name: task_name,
          task_description: metadata['description'] || '',
          targets: targets.split(',').map(&:strip),
          parameters: task_params,
          options: scrub_options_for_storage(options),
          job_id: response['id']
        )

        # Start background polling to update status
        ForemanTasks.async_task(Actions::ForemanOpenbolt::PollTaskStatus,
          response['id'],
          @smart_proxy.id)

        render json: {
          job_id: response['id'],
        }
      rescue ArgumentError => e
        # From merge_encrypted_defaults when a user submits the encrypted
        # placeholder for an option that has no saved Foreman setting.
        log_exception('launch_task', e)
        render_error(e.message, :bad_request)
      rescue ActiveRecord::RecordInvalid => e
        log_exception('launch_task', e)
        render_error("Database error: #{e.message}", :internal_server_error)
      rescue ProxyAPI::ProxyException => e
        log_exception('launch_task', e)
        render_error("Smart Proxy error: #{e.message}", :bad_gateway)
      rescue StandardError => e
        log_exception('launch_task', e)
        render_error("Error launching task: #{e.message}", :internal_server_error)
      end
    end

    def job_status
      return render_error('Task job not found', :not_found) unless @task_job

      render json: {
        status: @task_job.status,
        submitted_at: @task_job.submitted_at,
        completed_at: @task_job.completed_at,
        duration: @task_job.duration,
        task_name: @task_job.task_name,
        task_description: @task_job.task_description,
        task_parameters: @task_job.task_parameters,
        targets: @task_job.targets,
        smart_proxy: {
          id: @task_job.smart_proxy_id,
          name: @task_job.smart_proxy&.name || '(unknown)',
        },
      }
    end

    def job_result
      return render_error('Task job not found', :not_found) unless @task_job

      render json: {
        status: @task_job.status,
        command: @task_job.command,
        value: @task_job.result,
        log: @task_job.log,
      }
    end

    # List of all task history
    def fetch_task_history
      per_page = [(params[:per_page] || 20).to_i, 100].min
      @task_history = TaskJob.includes(:smart_proxy)
                             .recent
                             .paginate(page: params[:page], per_page: per_page)

      render json: {
        results: @task_history.map { |job| serialize_task_job(job) },
        total: @task_history.total_entries,
        page: @task_history.current_page,
        per_page: @task_history.per_page,
      }
    rescue StandardError => e
      log_exception('fetch_task_history', e)
      render_error("Error loading task history: #{e.message}", :internal_server_error)
    end

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
        log_exception("load_openbolt_api for proxy #{@smart_proxy.name}", e)
        render_error("Failed to connect to Smart Proxy", :bad_gateway)
        return false
      end

      true
    end

    def load_task_job
      job_id = params[:job_id]
      logger.debug("load_task_job - Job ID: #{job_id}")
      if job_id.blank?
        render_error('Job ID is required', :bad_request)
        return false
      end

      @task_job = TaskJob.find_by(job_id: job_id)
      logger.debug("load_task_job - Task Job: #{@task_job.inspect}")
    end

    def openbolt_settings
      @openbolt_settings ||= Foreman.settings.select { |s| s.name.start_with?('openbolt_') }
    end

    def encrypted_settings
      openbolt_settings.select(&:encrypted?)
    end

    def merge_encrypted_defaults(options)
      merged = options.dup
      merged.each do |key, value|
        next unless value == ENCRYPTED_PLACEHOLDER

        saved = Setting["openbolt_#{key}"]
        if saved.nil? || saved.to_s.empty?
          raise ArgumentError,
            "No saved value for encrypted option '#{key}'. Configure it in Administer > Settings or provide a value."
        end
        merged[key] = saved
      end
      merged
    end

    def scrub_options_for_storage(options)
      scrubbed = options.dup
      encrypted_settings.each do |setting|
        option_name = setting.name.sub(/^openbolt_/, '')
        scrubbed[option_name] = REDACTED_PLACEHOLDER if scrubbed.key?(option_name)
      end
      scrubbed
    end

    def render_openbolt_api_call(method_name, **args)
      result = @openbolt_api.send(method_name, **args)
      logger.debug("OpenBolt API call #{method_name} successful for proxy #{@smart_proxy.name}")
      render json: result
    rescue ProxyAPI::ProxyException => e
      log_exception(method_name, e)
      render_error("Smart Proxy error: #{e.message}", :bad_gateway)
    rescue StandardError => e
      log_exception(method_name, e)
      render_error("Internal server error: #{e.message}", :internal_server_error)
    end

    def log_exception(message, exception)
      logger.error("#{message}: #{exception.class}: #{exception.message}")
      logger.error(exception.backtrace.join("\n")) if exception.backtrace
    end

    def render_error(message, status)
      render json: { error: message }, status: status
    end

    def serialize_task_job(task_job)
      {
        job_id: task_job.job_id,
        task_name: task_job.task_name,
        task_description: task_job.task_description,
        task_parameters: task_job.task_parameters,
        targets: task_job.targets,
        status: task_job.status,
        smart_proxy: {
          id: task_job.smart_proxy_id,
          name: task_job.smart_proxy&.name || '(unknown)',
        },
        submitted_at: task_job.submitted_at,
        completed_at: task_job.completed_at,
        duration: task_job.duration,
      }
    end
  end
end

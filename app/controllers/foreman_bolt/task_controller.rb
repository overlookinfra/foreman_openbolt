# frozen_string_literal: true

require 'foreman_bolt/engine'
require 'proxy_api/bolt'

module ForemanBolt
  class TaskController < ::ApplicationController
    include ::Foreman::Controller::AutoCompleteSearch

    before_action :load_smart_proxy, only: [
      :fetch_tasks, :reload_tasks, :fetch_bolt_options, :execute_task, :job_status, :job_result
    ]
    before_action :load_bolt_api, only: [
      :fetch_tasks, :reload_tasks, :fetch_bolt_options, :execute_task, :job_status, :job_result
    ]

    # React-rendered pages
    def new_task
      render 'foreman_bolt/react_page'
    end

    def task_exec
      render 'foreman_bolt/react_page'
    end

    def fetch_tasks
      render_bolt_api_call(:tasks)
    end

    def reload_tasks
      render_bolt_api_call(:reload_tasks)
    end

    def fetch_bolt_options
      render_bolt_api_call(:bolt_options)
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

        expanded_targets = expand_targets(targets)
        return render_error('No valid hosts found for the specified targets', :bad_request) if expanded_targets.empty?

        logger.info("Executing Bolt task '#{task_name}' on targets '#{targets}' via proxy #{@smart_proxy.name}")

        response = @bolt_api.run_task(
          name: task_name,
          targets: expanded_targets.join(','),
          parameters: task_params,
          options: options
        )

        logger.info("Task execution response: #{response.inspect}")

        return render_error("Task execution failed: #{response['error']}", :bad_request) if response['error']

        return render_error('Task execution failed: No job ID returned', :bad_request) unless response['id']

        render json: {
          job_id: response['id'],
          proxy_id: @smart_proxy.id,
          proxy_name: @smart_proxy.name,
          target_count: expanded_targets.count,
        }
      rescue StandardError => e
        logger.error("Task execution error: #{e.class}: #{e.message}")
        logger.error("Backtrace: #{e.backtrace.first(5).join("\n")}")
        render_error("Error executing task: #{e.message}", :internal_server_error)
      end
    end

    def job_status
      job_id = params[:job_id]
      return render_error('Job ID is required', :bad_request) if job_id.blank?

      render_bolt_api_call(:job_status, job_id: job_id)
    end

    def job_result
      job_id = params[:job_id]
      return render_error('Job ID is required', :bad_request) if job_id.blank?

      render_bolt_api_call(:job_result, job_id: job_id)
    end

    private

    def expand_targets(targets_input)
      targets = []
      errors = []

      # Split by comma, but be careful with quoted strings
      parts = split_targets(targets_input)

      parts.each do |part|
        part = part.strip
        next if part.empty?

        if part.include?('hostgroup=')
          # Extract host group name and find hosts
          if match = part.match(/hostgroup="([^"]+)"/)
            group_name = match[1]
            targets.concat(hosts_from_hostgroup(group_name))
          end
        elsif part.include?('=') || part.include?('~') || part.include?(' and ') || part.include?(' or ')
          # This looks like a Foreman search query
          targets.concat(hosts_from_search(part))
        elsif host_exists?(part)
          # Direct host name - verify it exists
          targets << part
        else
          logger.warn("Host '#{part}' not found in Foreman")
          # Optionally still include it - Bolt might know about it
          targets << part
        end
      end

      targets.uniq
    end

    def split_targets(targets_input)
      parts = []
      current = ''
      in_quotes = false

      targets_input.each_char do |char|
        if char == '"'
          in_quotes = !in_quotes
          current += char
        elsif char == ',' && !in_quotes
          parts << current.strip unless current.strip.empty?
          current = ''
        else
          current += char
        end
      end

      parts << current.strip unless current.strip.empty?
      parts
    end

    # Helper: Get hosts from a host group
    def hosts_from_hostgroup(group_name)
      hostgroup = Hostgroup.find_by(name: group_name) || Hostgroup.find_by(title: group_name)

      if hostgroup
        # Get all hosts in this group and its children
        hosts = Host::Managed.where(hostgroup: hostgroup.subtree).pluck(:name)
        logger.info("Expanded host group '#{group_name}' to #{hosts.count} hosts")
        hosts
      else
        logger.warn("Host group '#{group_name}' not found")
        []
      end
    rescue StandardError => e
      logger.error("Error expanding host group '#{group_name}': #{e.message}")
      []
    end

    # Helper: Get hosts from a search query
    def hosts_from_search(search_query)
      # Use Foreman's search capability
      hosts = Host::Managed.search_for(search_query).pluck(:name)
      logger.info("Search query '#{search_query}' returned #{hosts.count} hosts")

      hosts
    rescue StandardError => e
      logger.error("Failed to expand search query '#{search_query}': #{e.message}")
      []
    end

    # Helper: Check if a host exists
    def host_exists?(hostname)
      Host::Managed.find_by(name: hostname).present?
    rescue StandardError
      false
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

    def load_bolt_api
      return false unless @smart_proxy
      return true if @bolt_api && @bolt_api.url == @smart_proxy.url

      begin
        @bolt_api = ProxyAPI::Bolt.new(url: @smart_proxy.url)
      rescue StandardError => e
        logger.error("Failed to initialize Bolt API for proxy #{@smart_proxy.name}: #{e.message}")
        render_error("Failed to connect to Smart Proxy", :bad_gateway)
        return false
      end

      true
    end

    def render_bolt_api_call(method_name, **args)
      result = @bolt_api.send(method_name, **args)
      logger.debug("Bolt API call #{method_name} successful for proxy #{@smart_proxy.name}")
      render json: result
    rescue ProxyAPI::ProxyException => e
      logger.error("Bolt API error for #{method_name}: #{e.message}")
      render_error("Smart Proxy error: #{e.message}", :bad_gateway)
    rescue StandardError => e
      logger.error("Unexpected error in #{method_name}: #{e.class}: #{e.message}")
      render_error("Internal server error: #{e.message}", :internal_server_error)
    end

    def render_error(message, status)
      render json: { error: message }, status: status
    end
  end
end

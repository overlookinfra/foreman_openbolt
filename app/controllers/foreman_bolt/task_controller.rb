# frozen_string_literal: true

require 'foreman_bolt/engine'
require 'proxy_api/bolt'

module ForemanBolt
  class TaskController < ::ApplicationController

    def new_task
      @smart_proxies = SmartProxy.all.order(:name)
      render template: 'foreman_bolt/new_task'
    end

    # Expects a proxy_id parameter
    # Used in JS on new_task page to populate task name dropdown
    def fetch_tasks
      render_api_call(:tasks, params[:proxy_id])
    end

    # Expects a proxy_id parameter
    # Used in JS on new_task page to reload tasks on the proxy
    def reload_tasks
      render_api_call(:reload_tasks, params[:proxy_id])
    end

    # Expects a proxy_id parameter
    # Used in JS on new_task page to get the bolt options
    def fetch_bolt_options
      render_api_call(:bolt_options, params[:proxy_id])
    end

    def task_exec
      proxy_id = params[:proxy_id]
      if proxy_id.present?
        return bad_proxy_response(proxy_id) unless load_api(proxy_id)
        begin
          response = @api.run_task(
            name: params[:task_name],
            targets: params[:targets],
            parameters: params[:params] || {},
            options: params[:options],
          )
          logger.info("Task execution response: #{response.inspect}")
          if response['error'] || response['id'].nil?
            flash[:error] = "Error executing task: #{response['error']}"
            redirect_to action: :new_task
            return
          end
          @proxy_id = @proxy.id
          @proxy_name = @proxy.name
          @job_id = response['id']
          render template: 'foreman_bolt/task_exec'
        rescue => e
          flash[:error] = "Error executing task: #{e.full_message}"
          redirect_to action: :new_task
        end
      else
        flash[:error] = 'Please select a Smart Proxy.'
        redirect_to action: :new_task
      end
    end

    def job_status
      render_api_call(:job_status, params[:proxy_id], job_id: params[:job_id])
    end

    def job_result
      render_api_call(:job_result, params[:proxy_id], job_id: params[:job_id])
    end

    private

    def load_api(proxy_id)
      return false if proxy_id.blank?
      if @proxy.nil? || @proxy.id != proxy_id.to_i
        @proxy = SmartProxy.find_by(id: proxy_id)
        return false unless @proxy
        @api = ProxyAPI::Bolt.new(url: @proxy.url)
      end
      true
    end

    def bad_proxy_response(proxy_id)
      flash[:error] = "Smart Proxy with ID #{proxy_id} not found."
      redirect_to action: :new_task
    end

    # Generally used for JS calls on the pages that expect a JSON response
    def render_api_call(function, proxy_id, **args)
      return bad_proxy_response(proxy_id) unless load_api(proxy_id)
      begin
        render json: @api.send(function, **args)
      rescue ProxyAPI::ProxyException => e
        render json: { error: e.message }, status: :bad_gateway
      end
    end
  end
end

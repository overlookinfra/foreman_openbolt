require 'foreman_bolt/engine'
require 'proxy_api/bolt'

module ForemanBolt
  class TaskController < ::ApplicationController
    # These are used in order to cache state to avoid multiple calls to the API
    @tasks = nil
    @proxy = nil

    def new_task
      @smart_proxies = SmartProxy.all.order(:name)
      render template: 'foreman_bolt/new_task'
    end

    # Expects a proxy_id parameter
    # Used in JS on new_task page to populate task name dropdown
    def fetch_tasks
      call_api(:tasks, params[:proxy_id])
    end

    # Expects a proxy_id parameter
    # Used in JS on new_task page to reload tasks on the proxy
    def reload_tasks
      call_api(:reload_tasks, params[:proxy_id])
    end

    # Expects a proxy_id parameter
    # Used in JS on new_task page to get the bolt options
    def fetch_bolt_options
      call_api(:bolt_options, params[:proxy_id])
    end

    def task_exec
      selected_proxy_id = params[:smart_proxy_id]
      if selected_proxy_id.present?
        @selected_proxy = SmartProxy.find(selected_proxy_id)
        render template: 'foreman_bolt/task_exec'
      else
        flash[:error] = 'Please select a Smart Proxy.'
        redirect_to action: :new_task
      end
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

    def call_api(function, proxy_id)
      return bad_proxy_response(proxy_id) unless load_api(proxy_id)
      render json: @api.send(function)
    rescue ProxyAPI::ProxyException => e
      render json: { error: e.message }, status: :bad_gateway
    end
  end
end

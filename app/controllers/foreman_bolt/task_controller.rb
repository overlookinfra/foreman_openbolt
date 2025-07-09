require 'foreman_bolt/engine'
require 'proxy_api/bolt'

module ForemanBolt
  class TaskController < ::ApplicationController

    # These are used in order to cache state to avoid multiple calls to the API
    @tasks = nil
    @proxy = nil

    ### Endpoint functions ###
    def render_run_task
      @smart_proxies = SmartProxy.all.order(:name)
      render template: 'foreman_bolt/run_task'
    end

    # Expects a proxy_id parameter
    # Used in JS on run_task page to populate task name dropdown
    def get_tasks
      return bad_proxy_response(params[:proxy_id]) unless load_api(params[:proxy_id])
      render json: @api.tasks
    rescue ProxyAPI::ProxyException => e
      render json: { error: e.message }, status: :bad_gateway
    end

    def reload_tasks
      return bad_proxy_response(params[:proxy_id]) unless load_api(params[:proxy_id])
      @api.reload_tasks
      render json: @api.tasks
    rescue ProxyAPI::ProxyException => e
      render json: { error: e.message }, status: :bad_gateway
    end

    def task_exec
      selected_proxy_id = params[:smart_proxy_id]
      if selected_proxy_id.present?
        @selected_proxy = SmartProxy.find(selected_proxy_id)
        render template: 'foreman_bolt/task_exec'
      else
        flash[:error] = 'Please select a Smart Proxy.'
        redirect_to action: :render_run_task
      end
    end

    ### Helper functions ###
    private

    def load_api(proxy_id)
      return false unless proxy_id.present?
      if @proxy.nil? || @proxy.id != proxy_id.to_i
        @proxy = SmartProxy.find_by(id: proxy_id)
        return false unless @proxy
        @api = ProxyAPI::Bolt.new(url: @proxy.url)
      end
      true
    end

    def bad_proxy_response(proxy_id)
      flash[:error] = "Smart Proxy with ID #{proxy_id} not found."
      redirect_to action: :render_run_task
    end
  end
end

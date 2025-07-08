require 'foreman_bolt/engine'
require 'proxy_api/bolt'

module ForemanBolt
  class TaskController < ::ApplicationController

    def render_run_task
      @smart_proxies = SmartProxy.all.order(:name)
      render template: 'foreman_bolt/run_task'
    end

    def get_tasks
      proxy = SmartProxy.find(params[:proxy_id])
      logger.info(proxy.url)
      names = ProxyAPI::Bolt.new(url: proxy.url).task_names
      logger.info(names)
      render json: names
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
  end
end

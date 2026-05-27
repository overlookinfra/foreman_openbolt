# frozen_string_literal: true

require 'foreman/logging'
require 'foreman_openbolt/engine'
require 'proxy_api/openbolt'

module ForemanOpenbolt
  class TaskController < ApplicationController
    # Rails checks rescue_from handlers in reverse registration order (last
    # registered is checked first). The StandardError catch-all must be
    # registered BEFORE the include so that the specific handlers registered
    # by Common's included block are checked first.
    rescue_from StandardError do |error|
      Foreman::Logging.exception('OpenBolt UI unexpected error', error)
      render_json_error("Internal server error: #{error.message}", :internal_server_error)
    end

    include ForemanOpenbolt::Jobs
    include ForemanOpenbolt::Tasks

    before_action :load_smart_proxy, only: [:tasks, :reload_tasks, :task_options, :launch_task]
    before_action :load_openbolt_api, only: [:tasks, :reload_tasks, :task_options, :launch_task]

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
  end
end

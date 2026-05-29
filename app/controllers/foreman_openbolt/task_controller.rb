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

    # tasks, reload_tasks, task_options, and launch_task come from
    # ForemanOpenbolt::Tasks; job_status, job_result, and jobs from
    # ForemanOpenbolt::Jobs.
  end
end

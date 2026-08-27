# frozen_string_literal: true

require 'foreman/logging'
require 'foreman_openbolt/engine'
require 'proxy_api/openbolt'

module ForemanOpenbolt
  class TaskController < ApplicationController
    # Rails checks rescue_from handlers in reverse registration order (last
    # registered is checked first). The StandardError catch-all must be
    # registered BEFORE the includes so that the specific handlers registered
    # by the other concerns' includes are checked first.
    rescue_from StandardError do |error|
      Foreman::Logging.exception('OpenBolt UI unexpected error', error)
      render_json_error('Internal server error', :internal_server_error)
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
  end
end

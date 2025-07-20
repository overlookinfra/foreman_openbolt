# frozen_string_literal: true

require 'json'

module ProxyAPI
  class Bolt < Resource
    def initialize(args)
      @url = args[:url]
      super args
    end

    def fetch_tasks
      @tasks = JSON.parse(get('/bolt/tasks').body)
    end

    def tasks
      @tasks ||= fetch_tasks
    end

    def reload_tasks
      @tasks = JSON.parse(get('/bolt/tasks/reload').body)
    end

    def task_names
      tasks.keys
    end

    def bolt_options
      @bolt_options ||= JSON.parse(get('/bolt/tasks/options').body)
    end

    def run_task(name:, targets:, parameters: {}, options: {})
      JSON.parse(post({
        name: name,
        targets: targets,
        parameters: parameters,
        options: options,
      }.to_json, '/bolt/run/task').body)
    end

    def job_status(job_id:)
      JSON.parse(get("/bolt/job/#{job_id}/status").body)
    end

    def job_result(job_id:)
      JSON.parse(get("/bolt/job/#{job_id}/result").body)
    end
  end
end

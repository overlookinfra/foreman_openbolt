# frozen_string_literal: true

require 'json'

module ProxyAPI
  class Openbolt < Resource
    def initialize(args)
      @url = args[:url]
      super args
    end

    def fetch_tasks
      @tasks = JSON.parse(get('/openbolt/tasks').body)
    end

    def tasks
      @tasks ||= fetch_tasks
    end

    def reload_tasks
      @tasks = JSON.parse(get('/openbolt/tasks/reload').body)
    end

    def task_names
      tasks.keys
    end

    def openbolt_options
      @openbolt_options ||= JSON.parse(get('/openbolt/tasks/options').body)
    end

    def run_task(name:, targets:, parameters: {}, options: {})
      JSON.parse(post({
        name: name,
        targets: targets,
        parameters: parameters,
        options: options,
      }.to_json, '/openbolt/run/task').body)
    end

    def job_status(job_id:)
      JSON.parse(get("/openbolt/job/#{job_id}/status").body)
    end

    def job_result(job_id:)
      JSON.parse(get("/openbolt/job/#{job_id}/result").body)
    end

    def delete_job_artifacts(job_id:)
      JSON.parse(delete("/openbolt/job/#{job_id}/artifacts").body)
    end
  end
end

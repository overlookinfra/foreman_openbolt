# frozen_string_literal: true

require 'json'

module ProxyAPI
  class Openbolt < Resource
    def initialize(args)
      @url = args[:url]
      super
    end

    def fetch_tasks
      @tasks = parse_response(get('/openbolt/tasks'), 'fetch_tasks')
    end

    def tasks
      @tasks ||= fetch_tasks
    end

    def reload_tasks
      @tasks = parse_response(get('/openbolt/tasks/reload'), 'reload_tasks')
    end

    def task_names
      tasks.keys
    end

    def openbolt_options
      @openbolt_options ||= parse_response(get('/openbolt/tasks/options'), 'openbolt_options')
    end

    def launch_task(name:, targets:, parameters: {}, options: {})
      response = post({
        name: name,
        targets: targets,
        parameters: parameters,
        options: options,
      }.to_json, '/openbolt/launch/task')
      parse_response(response, 'launch_task')
    end

    def job_status(job_id:)
      parse_response(get("/openbolt/job/#{job_id}/status"), 'job_status')
    end

    def job_result(job_id:)
      parse_response(get("/openbolt/job/#{job_id}/result"), 'job_result')
    end

    def delete_job_artifacts(job_id:)
      parse_response(delete("/openbolt/job/#{job_id}/artifacts"), 'delete_job_artifacts')
    end

    def parse_response(response, operation)
      raise ProxyException.new(@url, nil, "No response from Smart Proxy during #{operation}") unless response

      body = response.body
      raise ProxyException.new(@url, nil, "Empty response body from Smart Proxy during #{operation}") if body.nil?

      JSON.parse(body)
    rescue JSON::ParserError => e
      raise ProxyException.new(
        @url, nil,
        "Invalid JSON from Smart Proxy during #{operation}: #{e.message}. " \
        "Response body (first 500 chars): #{body.to_s[0..500]}"
      )
    end
  end
end

# frozen_string_literal: true

require 'json'

module ProxyAPI
  class Openbolt < Resource
    # A 200 response carrying the proxy's {"error": {...}} result. This is a final,
    # permanent error, unlike a transport-level ProxyException, so callers should not retry.
    class ProxyReportedError < ProxyException; end

    def initialize(args)
      @url = args[:url]
      super
    end

    def fetch_tasks
      @tasks = with_proxy_error_handling('fetch_tasks') do
        parse_response(get('/openbolt/tasks'), 'fetch_tasks')
      end
    end

    def tasks
      @tasks ||= fetch_tasks
    end

    def reload_tasks
      @tasks = with_proxy_error_handling('reload_tasks') do
        parse_response(get('/openbolt/tasks/reload'), 'reload_tasks')
      end
    end

    def task_names
      tasks.keys
    end

    def openbolt_options
      @openbolt_options ||= with_proxy_error_handling('openbolt_options') do
        parse_response(get('/openbolt/tasks/options'), 'openbolt_options')
      end
    end

    # Passes the proxy's error result through so a rejected launch renders
    # as a 400 at the caller, not a 502.
    def launch_task(name:, targets:, parameters: {}, options: {})
      with_transport_errors_wrapped('launch_task') do
        response = post({
          name: name,
          targets: targets,
          parameters: parameters,
          options: options,
        }.to_json, '/openbolt/launch/task')
        parse_response(response, 'launch_task')
      end
    end

    def job_status(job_id:)
      with_proxy_error_handling('job_status') do
        parse_response(get("/openbolt/job/#{job_id}/status"), 'job_status')
      end
    end

    def job_result(job_id:)
      with_proxy_error_handling('job_result') do
        parse_response(get("/openbolt/job/#{job_id}/result"), 'job_result')
      end
    end

    def delete_job_artifacts(job_id:)
      with_proxy_error_handling('delete_job_artifacts') do
        parse_response(delete("/openbolt/job/#{job_id}/artifacts"), 'delete_job_artifacts')
      end
    end

    def parse_response(response, operation)
      unless response
        raise ProxyException.new(
          @url, RuntimeError.new("No response from Smart Proxy during #{operation}"),
          "No response from Smart Proxy during #{operation}"
        )
      end

      body = response.body
      if body.nil?
        raise ProxyException.new(
          @url, RuntimeError.new("Empty response body from Smart Proxy during #{operation}"),
          "Empty response body from Smart Proxy during #{operation}"
        )
      end

      JSON.parse(body)
    rescue JSON::ParserError => e
      raise ProxyException.new(
        @url, e,
        "Invalid JSON from Smart Proxy during #{operation}: #{e.message}. " \
        "Response body (first 500 chars): #{body.to_s[0..500]}"
      )
    end

    private

    # Rewraps transport-layer failures as ProxyException so callers never
    # see raw RestClient::Exception / Errno::* and there's only one type
    # of exception to handle for this kind of error.
    def with_transport_errors_wrapped(operation)
      yield
    rescue RestClient::Exception, SystemCallError, SocketError, OpenSSL::SSL::SSLError => e
      raise ProxyException.new(
        @url, e,
        "Transport error during #{operation}: #{e.message}"
      )
    end

    # Raises ProxyReportedError when a 200 body carries the proxy's error
    # result, which is always {"error": {"message": ...}}. Requiring that
    # exact shape avoids false positives on real data, like a task named
    # 'error' in the fetch_tasks response.
    def with_proxy_error_handling(operation, &block)
      result = with_transport_errors_wrapped(operation, &block)
      error = result.is_a?(Hash) ? result['error'] : nil
      if error.is_a?(Hash) && error.key?('message')
        detail = error['message']
        raise ProxyReportedError.new(
          @url, RuntimeError.new(detail.to_s),
          "Smart Proxy reported error during #{operation}: #{detail}"
        )
      end
      result
    end
  end
end

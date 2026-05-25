# frozen_string_literal: true

require 'json'

module ProxyAPI
  class Openbolt < Resource
    # Raised when the proxy returns a 200 with an {"error": {...}} body
    # (its convention for domain-level errors). Distinguished from base
    # ProxyException (transport / parse failure) so callers can treat
    # proxy-reported errors as permanent rather than retrying them.
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

    # launch_task wraps transport errors but passes the proxy's
    # {"error": ...} envelope through to the caller, because that envelope
    # means "your launch was rejected" (e.g. unknown task) and the caller
    # renders it as a 400, not a 502.
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

    # Catches transport-layer failures (RestClient HTTP errors, socket errors,
    # SSL errors) and rewraps them as ProxyException. Most ProxyAPI subclasses
    # in Foreman do this through the base Resource class. Ours doesn't, so
    # callers used to see raw RestClient::Exception / Errno::* propagating.
    def with_transport_errors_wrapped(operation)
      yield
    rescue RestClient::Exception, SystemCallError, SocketError, OpenSSL::SSL::SSLError => e
      raise ProxyException.new(
        @url, e,
        "Transport error during #{operation}: #{e.message}"
      )
    end

    # On top of transport wrapping, treat a 200-with-{"error": ...} body as a
    # proxy-reported error and raise ProxyReportedError. Without this every
    # consumer except launch_task (which had its own check) silently surfaced
    # proxy errors as successful empty-shaped responses.
    def with_proxy_error_handling(operation, &block)
      result = with_transport_errors_wrapped(operation, &block)
      if result.is_a?(Hash) && result['error']
        detail = result['error'].is_a?(Hash) ? result['error']['message'] : result['error']
        raise ProxyReportedError.new(
          @url, RuntimeError.new(detail.to_s),
          "Smart Proxy reported error during #{operation}: #{detail}"
        )
      end
      result
    end
  end
end

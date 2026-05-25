# frozen_string_literal: true

require 'test_plugin_helper'

class ProxyApiOpenboltTest < ForemanOpenbolt::PluginTestCase
  PROXY_URL = 'https://proxy.example.com:8443'

  setup do
    @api = ProxyAPI::Openbolt.new(url: PROXY_URL)
  end

  context 'task_names' do
    test 'returns task names from fetched tasks' do
      tasks = { 'mymod::install' => {}, 'mymod::mytask' => {} }
      stub_request(:get, "#{PROXY_URL}/openbolt/tasks")
        .to_return(status: 200, body: tasks.to_json, headers: { 'Content-Type' => 'application/json' })

      assert_equal %w[mymod::install mymod::mytask], @api.task_names
    end
  end

  context 'fetch_tasks' do
    test 'fetches and parses task list from proxy' do
      tasks = { 'mymod::install' => { 'description' => 'Install a package' } }
      stub_request(:get, "#{PROXY_URL}/openbolt/tasks")
        .to_return(status: 200, body: tasks.to_json, headers: { 'Content-Type' => 'application/json' })

      result = @api.fetch_tasks
      assert_equal tasks, result
    end

    test 'wraps proxy HTTP errors as ProxyException' do
      stub_request(:get, "#{PROXY_URL}/openbolt/tasks")
        .to_return(status: 500, body: 'Internal Server Error')

      # ProxyAPI::Openbolt now rewraps RestClient::Exception (and Errno::*,
      # SocketError, OpenSSL::SSL::SSLError) as ProxyException so callers
      # get a uniform handler instead of leaking transport-layer classes.
      assert_raises(ProxyAPI::ProxyException) { @api.fetch_tasks }
    end

    test 'raises ProxyException on unparseable response body' do
      stub_request(:get, "#{PROXY_URL}/openbolt/tasks")
        .to_return(status: 200, body: nil)

      assert_raises(ProxyAPI::ProxyException) { @api.fetch_tasks }
    end

    test 'raises ProxyException on invalid JSON' do
      stub_request(:get, "#{PROXY_URL}/openbolt/tasks")
        .to_return(status: 200, body: 'not json', headers: { 'Content-Type' => 'text/plain' })

      assert_raises(ProxyAPI::ProxyException) { @api.fetch_tasks }
    end
  end

  context 'reload_tasks' do
    test 'fetches from reload endpoint and updates cached tasks' do
      original_tasks = { 'mymod::install' => { 'description' => 'Install something' } }
      stub_request(:get, "#{PROXY_URL}/openbolt/tasks")
        .to_return(status: 200, body: original_tasks.to_json, headers: { 'Content-Type' => 'application/json' })

      assert_equal original_tasks, @api.tasks

      reloaded_tasks = { 'mymod::install' => {}, 'mymod::mytask' => { 'description' => 'A new task' } }
      stub_request(:get, "#{PROXY_URL}/openbolt/tasks/reload")
        .to_return(status: 200, body: reloaded_tasks.to_json, headers: { 'Content-Type' => 'application/json' })

      result = @api.reload_tasks
      assert_equal reloaded_tasks, result
      assert_equal reloaded_tasks, @api.tasks
    end
  end

  context 'openbolt_options' do
    test 'fetches and parses options from proxy' do
      options = { 'transport' => { 'type' => 'string', 'default' => 'ssh' } }
      stub_request(:get, "#{PROXY_URL}/openbolt/tasks/options")
        .to_return(status: 200, body: options.to_json, headers: { 'Content-Type' => 'application/json' })

      result = @api.openbolt_options
      assert_equal options, result
    end

    test 'memoizes the result' do
      options = { 'transport' => { 'type' => 'string' } }
      stub = stub_request(:get, "#{PROXY_URL}/openbolt/tasks/options")
             .to_return(status: 200, body: options.to_json, headers: { 'Content-Type' => 'application/json' })

      @api.openbolt_options
      @api.openbolt_options
      assert_requested(stub, times: 1)
    end
  end

  context 'launch_task' do
    test 'posts task request and returns parsed response' do
      response_body = { 'id' => 'job-abc-123' }
      stub_request(:post, "#{PROXY_URL}/openbolt/launch/task")
        .to_return(status: 200, body: response_body.to_json, headers: { 'Content-Type' => 'application/json' })

      result = @api.launch_task(
        name: 'mymod::install',
        targets: 'host1.example.com',
        parameters: { 'name' => 'nginx' },
        options: { 'transport' => 'ssh' }
      )
      assert_equal response_body, result
    end

    test 'sends correct JSON payload with parameters, options, and targets' do
      stub = stub_request(:post, "#{PROXY_URL}/openbolt/launch/task")
             .with do |request|
        body = JSON.parse(request.body)
        body['name'] == 'mymod::mytask' &&
          body['targets'] == 'host1.example.com,host2.example.com' &&
          body['parameters'] == { 'name' => 'nginx', 'version' => '1.0' } &&
          body['options'] == { 'transport' => 'ssh', 'run-as' => 'root' }
      end
             .to_return(status: 200, body: '{"id": "job-1"}', headers: { 'Content-Type' => 'application/json' })

      @api.launch_task(
        name: 'mymod::mytask',
        targets: 'host1.example.com,host2.example.com',
        parameters: { 'name' => 'nginx', 'version' => '1.0' },
        options: { 'transport' => 'ssh', 'run-as' => 'root' }
      )
      assert_requested(stub)
    end
  end

  context 'job_status' do
    test 'fetches job status by ID' do
      status_body = { 'status' => 'running' }
      stub_request(:get, "#{PROXY_URL}/openbolt/job/test-123/status")
        .to_return(status: 200, body: status_body.to_json, headers: { 'Content-Type' => 'application/json' })

      result = @api.job_status(job_id: 'test-123')
      assert_equal status_body, result
    end
  end

  context 'job_result' do
    test 'fetches job result by ID' do
      result_body = { 'value' => { 'items' => [] }, 'log' => 'done' }
      stub_request(:get, "#{PROXY_URL}/openbolt/job/test-123/result")
        .to_return(status: 200, body: result_body.to_json, headers: { 'Content-Type' => 'application/json' })

      result = @api.job_result(job_id: 'test-123')
      assert_equal result_body, result
    end
  end

  context 'delete_job_artifacts' do
    test 'sends DELETE for job artifacts' do
      stub_request(:delete, "#{PROXY_URL}/openbolt/job/test-123/artifacts")
        .to_return(status: 200, body: '{"deleted": true}', headers: { 'Content-Type' => 'application/json' })

      result = @api.delete_job_artifacts(job_id: 'test-123')
      assert_equal({ 'deleted' => true }, result)
    end
  end

  context 'connection errors' do
    test 'wraps timeouts as ProxyException' do
      stub_request(:get, "#{PROXY_URL}/openbolt/tasks").to_timeout

      assert_raises(ProxyAPI::ProxyException) { @api.fetch_tasks }
    end

    test 'wraps connection refused as ProxyException' do
      stub_request(:get, "#{PROXY_URL}/openbolt/tasks").to_raise(Errno::ECONNREFUSED)

      assert_raises(ProxyAPI::ProxyException) { @api.fetch_tasks }
    end

    test 'wraps SocketError as ProxyException' do
      stub_request(:get, "#{PROXY_URL}/openbolt/tasks").to_raise(SocketError.new('host not found'))

      assert_raises(ProxyAPI::ProxyException) { @api.fetch_tasks }
    end

    test 'wraps SSL errors as ProxyException' do
      stub_request(:get, "#{PROXY_URL}/openbolt/tasks")
        .to_raise(OpenSSL::SSL::SSLError.new('bad cert'))

      assert_raises(ProxyAPI::ProxyException) { @api.fetch_tasks }
    end
  end

  # The smart proxy returns domain-level errors as HTTP 200 with
  # {"error": {"message": "..."}} (see smart_proxy_openbolt/api.rb's
  # catch_errors helper). Before this layer was added, every consumer
  # except launch_task silently surfaced those as success responses,
  # so a "Job not found" reply looked indistinguishable from a real
  # result. ProxyReportedError makes this loud everywhere except
  # launch_task, which passes the envelope through so the caller can
  # render it as 400 (your task name was bad) instead of 502.
  context 'proxy-reported errors (200 + error envelope)' do
    error_body = { 'error' => { 'message' => 'Job not found: bogus' } }.to_json

    test 'fetch_tasks raises ProxyReportedError' do
      stub_request(:get, "#{PROXY_URL}/openbolt/tasks")
        .to_return(status: 200, body: error_body, headers: { 'Content-Type' => 'application/json' })

      error = assert_raises(ProxyAPI::Openbolt::ProxyReportedError) { @api.fetch_tasks }
      assert_match(/Job not found: bogus/, error.message)
    end

    test 'reload_tasks raises ProxyReportedError' do
      stub_request(:get, "#{PROXY_URL}/openbolt/tasks/reload")
        .to_return(status: 200, body: error_body, headers: { 'Content-Type' => 'application/json' })

      assert_raises(ProxyAPI::Openbolt::ProxyReportedError) { @api.reload_tasks }
    end

    test 'openbolt_options raises ProxyReportedError' do
      stub_request(:get, "#{PROXY_URL}/openbolt/tasks/options")
        .to_return(status: 200, body: error_body, headers: { 'Content-Type' => 'application/json' })

      assert_raises(ProxyAPI::Openbolt::ProxyReportedError) { @api.openbolt_options }
    end

    test 'job_status raises ProxyReportedError' do
      stub_request(:get, "#{PROXY_URL}/openbolt/job/test-123/status")
        .to_return(status: 200, body: error_body, headers: { 'Content-Type' => 'application/json' })

      assert_raises(ProxyAPI::Openbolt::ProxyReportedError) { @api.job_status(job_id: 'test-123') }
    end

    test 'job_result raises ProxyReportedError' do
      stub_request(:get, "#{PROXY_URL}/openbolt/job/test-123/result")
        .to_return(status: 200, body: error_body, headers: { 'Content-Type' => 'application/json' })

      assert_raises(ProxyAPI::Openbolt::ProxyReportedError) { @api.job_result(job_id: 'test-123') }
    end

    test 'delete_job_artifacts raises ProxyReportedError' do
      stub_request(:delete, "#{PROXY_URL}/openbolt/job/test-123/artifacts")
        .to_return(status: 200, body: error_body, headers: { 'Content-Type' => 'application/json' })

      assert_raises(ProxyAPI::Openbolt::ProxyReportedError) { @api.delete_job_artifacts(job_id: 'test-123') }
    end

    # launch_task INTENTIONALLY passes the envelope through. The caller
    # (Tasks#dispatch_task) re-raises as LaunchError so the controller can
    # render 400 instead of 502 ("your task name was rejected" is a client
    # error from the user's perspective, not a proxy outage).
    test 'launch_task returns the error envelope unchanged' do
      stub_request(:post, "#{PROXY_URL}/openbolt/launch/task")
        .to_return(status: 200, body: error_body, headers: { 'Content-Type' => 'application/json' })

      result = @api.launch_task(name: 'bogus', targets: 'host1', parameters: {}, options: {})
      assert_equal('Job not found: bogus', result['error']['message'])
    end

    test 'launch_task still wraps transport errors' do
      stub_request(:post, "#{PROXY_URL}/openbolt/launch/task").to_timeout

      assert_raises(ProxyAPI::ProxyException) do
        @api.launch_task(name: 'mymod::install', targets: 'host1', parameters: {}, options: {})
      end
    end

    test 'ProxyReportedError is a ProxyException so existing rescue_from chains catch it' do
      stub_request(:get, "#{PROXY_URL}/openbolt/tasks")
        .to_return(status: 200, body: error_body, headers: { 'Content-Type' => 'application/json' })

      assert_raises(ProxyAPI::ProxyException) { @api.fetch_tasks }
    end

    test 'top-level error key with a string value also raises ProxyReportedError' do
      stub_request(:get, "#{PROXY_URL}/openbolt/tasks")
        .to_return(status: 200, body: { 'error' => 'Plain string error' }.to_json,
          headers: { 'Content-Type' => 'application/json' })

      error = assert_raises(ProxyAPI::Openbolt::ProxyReportedError) { @api.fetch_tasks }
      assert_match(/Plain string error/, error.message)
    end
  end
end

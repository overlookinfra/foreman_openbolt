# frozen_string_literal: true

require 'test_plugin_helper'

class PollTaskStatusTest < ForemanOpenbolt::PluginTestCase
  include Dynflow::Testing

  context 'extract_proxy_error' do
    setup do
      @action = create_action(Actions::ForemanOpenbolt::PollTaskStatus)
    end

    test 'returns nil for nil response' do
      assert_nil @action.extract_proxy_error(nil)
    end

    test 'returns nil when no error key' do
      assert_nil @action.extract_proxy_error({ 'status' => 'running' })
    end

    test 'returns nil for empty error string' do
      assert_nil @action.extract_proxy_error({ 'error' => '' })
    end

    test 'returns string error directly' do
      assert_equal 'something broke', @action.extract_proxy_error({ 'error' => 'something broke' })
    end

    test 'returns message from hash error' do
      assert_equal 'detailed error', @action.extract_proxy_error({ 'error' => { 'message' => 'detailed error' } })
    end

    test 'returns stringified hash when no message key' do
      error_hash = { 'code' => 500 }
      result = @action.extract_proxy_error({ 'error' => error_hash })
      assert_equal error_hash.to_s, result
    end
  end

  context 'plan' do
    test 'stores job_id and proxy_id in input' do
      action = create_and_plan_action(Actions::ForemanOpenbolt::PollTaskStatus, 'job-123', 42)
      assert_equal 'job-123', action.input[:job_id]
      assert_equal 42, action.input[:proxy_id]
    end
  end

  context 'rescue_strategy' do
    test 'uses Skip rescue strategy' do
      action = create_action(Actions::ForemanOpenbolt::PollTaskStatus)
      assert_equal Dynflow::Action::Rescue::Skip, action.rescue_strategy
    end
  end

  context 'poll_and_reschedule' do
    setup do
      @proxy = FactoryBot.create(:smart_proxy)
      @job = FactoryBot.create(:task_job, :running, smart_proxy: @proxy)
    end

    test 'polls proxy and keeps status when unchanged' do
      status_stub = stub_request(:get, "#{@proxy.url}/openbolt/job/#{@job.job_id}/status")
                    .to_return(status: 200, body: { 'status' => 'running' }.to_json,
                      headers: { 'Content-Type' => 'application/json' })

      action = create_and_plan_action(Actions::ForemanOpenbolt::PollTaskStatus, @job.job_id, @proxy.id)
      run_action(action)

      assert_requested(status_stub)
      assert_equal 'running', @job.reload.status
    end

    test 'fetches result when job completes' do
      stub_request(:get, "#{@proxy.url}/openbolt/job/#{@job.job_id}/status")
        .to_return(status: 200, body: { 'status' => 'success' }.to_json,
          headers: { 'Content-Type' => 'application/json' })

      result_body = { 'status' => 'success', 'value' => { 'items' => [] }, 'log' => 'done',
                      'command' => 'bolt task run test' }
      stub_request(:get, "#{@proxy.url}/openbolt/job/#{@job.job_id}/result")
        .to_return(status: 200, body: result_body.to_json,
          headers: { 'Content-Type' => 'application/json' })

      ForemanTasks.stubs(:async_task)
      action = create_and_plan_action(Actions::ForemanOpenbolt::PollTaskStatus, @job.job_id, @proxy.id)
      run_action(action)

      @job.reload
      assert_equal 'success', @job.status
      assert_equal({ 'items' => [] }, @job.result)
      assert_equal 'done', @job.log
    end

    test 'finishes cleanly when task job not found' do
      action = create_and_plan_action(Actions::ForemanOpenbolt::PollTaskStatus, 'nonexistent-id', @proxy.id)
      assert_nothing_raised { run_action(action) }
    end

    test 'marks exception when proxy not found' do
      action = create_and_plan_action(Actions::ForemanOpenbolt::PollTaskStatus, @job.job_id, -1)
      run_action(action)

      assert_equal 'exception', @job.reload.status
    end

    test 'marks exception immediately on proxy application error' do
      status_stub = stub_request(:get, "#{@proxy.url}/openbolt/job/#{@job.job_id}/status")
                    .to_return(status: 200, body: { 'error' => { 'message' => 'Job not found: test-job' } }.to_json,
                      headers: { 'Content-Type' => 'application/json' })

      action = create_and_plan_action(Actions::ForemanOpenbolt::PollTaskStatus, @job.job_id, @proxy.id)
      run_action(action)

      assert_requested(status_stub)
      assert_equal 'exception', @job.reload.status
    end

    test 'marks exception immediately when proxy response has no status' do
      stub_request(:get, "#{@proxy.url}/openbolt/job/#{@job.job_id}/status")
        .to_return(status: 200, body: { 'unexpected' => 'data' }.to_json,
          headers: { 'Content-Type' => 'application/json' })

      action = create_and_plan_action(Actions::ForemanOpenbolt::PollTaskStatus, @job.job_id, @proxy.id)
      run_action(action)

      assert_equal 'exception', @job.reload.status
    end

    test 'marks job as exception after exhausting retry limit' do
      stub_request(:get, "#{@proxy.url}/openbolt/job/#{@job.job_id}/status")
        .to_return(status: 500, body: 'Internal Server Error')

      action = create_and_plan_action(Actions::ForemanOpenbolt::PollTaskStatus, @job.job_id, @proxy.id)
      # Set retry count to just above the limit so the next error triggers exhaustion
      action.input[:retry_count] = Actions::ForemanOpenbolt::PollTaskStatus::RETRY_LIMIT
      run_action(action)

      assert_equal 'exception', @job.reload.status
    end
  end
end

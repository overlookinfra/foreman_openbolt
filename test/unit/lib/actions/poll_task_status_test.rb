# frozen_string_literal: true

require 'test_plugin_helper'

class PollTaskStatusTest < ForemanOpenbolt::PluginTestCase
  include Dynflow::Testing

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

    test 'marks exception immediately on proxy application error from job_status' do
      status_stub = stub_request(:get, "#{@proxy.url}/openbolt/job/#{@job.job_id}/status")
                    .to_return(status: 200, body: { 'error' => { 'message' => 'Job not found: test-job' } }.to_json,
                      headers: { 'Content-Type' => 'application/json' })

      action = create_and_plan_action(Actions::ForemanOpenbolt::PollTaskStatus, @job.job_id, @proxy.id)
      run_action(action)

      assert_requested(status_stub)
      assert_equal 'exception', @job.reload.status
    end

    test 'marks exception immediately on proxy application error from job_result' do
      stub_request(:get, "#{@proxy.url}/openbolt/job/#{@job.job_id}/status")
        .to_return(status: 200, body: { 'status' => 'success' }.to_json,
          headers: { 'Content-Type' => 'application/json' })
      result_stub = stub_request(:get, "#{@proxy.url}/openbolt/job/#{@job.job_id}/result")
                    .to_return(status: 200,
                      body: { 'error' => { 'message' => 'Result file not found for job' } }.to_json,
                      headers: { 'Content-Type' => 'application/json' })

      action = create_and_plan_action(Actions::ForemanOpenbolt::PollTaskStatus, @job.job_id, @proxy.id)
      run_action(action)

      assert_requested(result_stub)
      assert_equal 'exception', @job.reload.status
    end

    test 'does not strand the job when result fetch fails transiently after completion' do
      stub_request(:get, "#{@proxy.url}/openbolt/job/#{@job.job_id}/status")
        .to_return(status: 200, body: { 'status' => 'success' }.to_json,
          headers: { 'Content-Type' => 'application/json' })
      result_stub = stub_request(:get, "#{@proxy.url}/openbolt/job/#{@job.job_id}/result")
                    .to_return(status: 500, body: 'Internal Server Error')

      action = create_and_plan_action(Actions::ForemanOpenbolt::PollTaskStatus, @job.job_id, @proxy.id)
      run = run_action(action)

      assert_requested(result_stub)
      @job.reload
      assert_equal 'running', @job.status
      assert_nil @job.result
      assert_equal 1, run.input[:retry_count]
    end

    test 'marks exception when the result fetch keeps failing past the retry limit after completion' do
      stub_request(:get, "#{@proxy.url}/openbolt/job/#{@job.job_id}/status")
        .to_return(status: 200, body: { 'status' => 'success' }.to_json,
          headers: { 'Content-Type' => 'application/json' })
      stub_request(:get, "#{@proxy.url}/openbolt/job/#{@job.job_id}/result")
        .to_return(status: 500, body: 'Internal Server Error')

      action = create_and_plan_action(Actions::ForemanOpenbolt::PollTaskStatus, @job.job_id, @proxy.id)
      action.input[:retry_count] = Actions::ForemanOpenbolt::PollTaskStatus::RETRY_LIMIT
      run_action(action)

      @job.reload
      assert_equal 'exception', @job.status
      assert_nil @job.result
    end

    test 'records completed status when proxy returns a blank result body' do
      stub_request(:get, "#{@proxy.url}/openbolt/job/#{@job.job_id}/status")
        .to_return(status: 200, body: { 'status' => 'success' }.to_json,
          headers: { 'Content-Type' => 'application/json' })
      stub_request(:get, "#{@proxy.url}/openbolt/job/#{@job.job_id}/result")
        .to_return(status: 200, body: {}.to_json,
          headers: { 'Content-Type' => 'application/json' })

      action = create_and_plan_action(Actions::ForemanOpenbolt::PollTaskStatus, @job.job_id, @proxy.id)
      run_action(action)

      @job.reload
      assert_equal 'success', @job.status
      assert_nil @job.result
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
      action.input[:retry_count] = Actions::ForemanOpenbolt::PollTaskStatus::RETRY_LIMIT
      run_action(action)

      assert_equal 'exception', @job.reload.status
    end

    test 'does not raise when exception flip itself fails after retry exhaustion' do
      stub_request(:get, "#{@proxy.url}/openbolt/job/#{@job.job_id}/status")
        .to_return(status: 500, body: 'Internal Server Error')
      ::ForemanOpenbolt::TaskJob.any_instance.stubs(:update!).raises(
        ActiveRecord::RecordInvalid.new(ForemanOpenbolt::TaskJob.new)
      )

      action = create_and_plan_action(Actions::ForemanOpenbolt::PollTaskStatus, @job.job_id, @proxy.id)
      action.input[:retry_count] = Actions::ForemanOpenbolt::PollTaskStatus::RETRY_LIMIT

      assert_nothing_raised { run_action(action) }
      assert_equal 'running', @job.reload.status
    end

    test 'does not raise when exception flip itself fails after proxy not found' do
      ::ForemanOpenbolt::TaskJob.any_instance.stubs(:update!).raises(
        ActiveRecord::RecordInvalid.new(ForemanOpenbolt::TaskJob.new)
      )

      action = create_and_plan_action(Actions::ForemanOpenbolt::PollTaskStatus, @job.job_id, -1)

      assert_nothing_raised { run_action(action) }
      assert_equal 'running', @job.reload.status
    end

    test 'does not raise when exception flip itself fails after proxy-reported error' do
      stub_request(:get, "#{@proxy.url}/openbolt/job/#{@job.job_id}/status")
        .to_return(status: 200,
          body: { 'error' => { 'message' => 'Job not found on proxy' } }.to_json,
          headers: { 'Content-Type' => 'application/json' })
      ::ForemanOpenbolt::TaskJob.any_instance.stubs(:update!).raises(
        ActiveRecord::RecordInvalid.new(ForemanOpenbolt::TaskJob.new)
      )

      action = create_and_plan_action(Actions::ForemanOpenbolt::PollTaskStatus, @job.job_id, @proxy.id)
      action.input[:retry_count] = 5

      run = nil
      assert_nothing_raised do
        run = run_action(action)
      end
      # The stubbed update! never wrote 'exception'.
      assert_equal 'running', @job.reload.status
      assert_equal 5, run.input[:retry_count]
    end
  end
end

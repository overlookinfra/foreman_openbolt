# frozen_string_literal: true

require_relative '../../api_acceptance_helper'

# Tests POST /api/v2/openbolt/launch/task: validation, error envelope, and
# one full end-to-end smoke test that launches a real bolt task and reads
# the result back.
class ApiLaunchTest < ApiAcceptanceTestCase
  def test_launch_returns_job_id_and_kind
    resp = @api.post('/api/v2/openbolt/launch/task',
      smart_proxy_id: smart_proxy_id,
      task_name: 'acceptance::noop_task',
      targets: 'target1.example.com',
      parameters: {})
    assert_equal 201, resp.status, resp.body.inspect
    assert resp.body['job_id'].is_a?(String) && !resp.body['job_id'].empty?,
      "expected non-empty job_id, got: #{resp.body.inspect}"
    assert_equal 'task', resp.body['kind']
  end

  def test_launch_returns_400_when_smart_proxy_id_is_missing
    resp = @api.post('/api/v2/openbolt/launch/task',
      task_name: 'acceptance::noop_task',
      targets: 'target1.example.com',
      parameters: {})
    assert_equal 400, resp.status, resp.body.inspect
    assert_kind_of Hash, resp.body['error']
    assert_equal 'Smart Proxy ID is required', resp.body.dig('error', 'message')
  end

  def test_launch_returns_400_when_task_name_is_missing
    resp = @api.post('/api/v2/openbolt/launch/task',
      smart_proxy_id: smart_proxy_id,
      targets: 'target1.example.com',
      parameters: {})
    assert_equal 400, resp.status, resp.body.inspect
    assert_match(/Task name and targets cannot be empty/, resp.body.dig('error', 'message').to_s)
  end

  def test_launch_returns_400_when_targets_is_missing
    resp = @api.post('/api/v2/openbolt/launch/task',
      smart_proxy_id: smart_proxy_id,
      task_name: 'acceptance::noop_task',
      parameters: {})
    assert_equal 400, resp.status, resp.body.inspect
    assert_match(/Task name and targets cannot be empty/, resp.body.dig('error', 'message').to_s)
  end

  def test_launch_returns_400_when_task_does_not_exist_on_proxy
    # The proxy responds with an {error: ...} envelope for an unknown
    # task; ForemanOpenbolt::Tasks#dispatch_task re-raises that as a
    # LaunchError, which the API controller renders as 400.
    resp = @api.post('/api/v2/openbolt/launch/task',
      smart_proxy_id: smart_proxy_id,
      task_name: 'acceptance::does_not_exist',
      targets: 'target1.example.com',
      parameters: {})
    assert_equal 400, resp.status, resp.body.inspect
    assert_match(/Task execution failed/, resp.body.dig('error', 'message').to_s)
  end

  # End-to-end smoke: exercises launch + status poll + result fetch with
  # real bolt execution against real targets. If this passes, the wiring
  # from the API controller all the way through ProxyAPI to smart proxy
  # to bolt to PollTaskStatus to TaskJob is working.
  def test_echo_task_end_to_end
    message = "acceptance api e2e #{Time.now.to_i}"
    job_id = launch_and_wait_for(
      task: 'acceptance::echo',
      params: { 'message' => message }
    )

    result_resp = @api.get("/api/v2/openbolt/jobs/#{job_id}/result")
    assert_equal 200, result_resp.status, result_resp.body.inspect
    assert_equal 'success', result_resp.body['status'], result_resp.body.inspect
    assert_equal 'task', result_resp.body['kind']
    assert_match(/acceptance::echo/, result_resp.body['command'].to_s)
    # The bolt task returns {message, hostname}; value is the unmodified
    # bolt result hash (per-target results indexed by target).
    assert_match(/#{Regexp.escape(message)}/, result_resp.body['value'].to_s)
  end
end

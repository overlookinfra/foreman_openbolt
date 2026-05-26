# frozen_string_literal: true

require_relative '../../api_acceptance_helper'

# Tests authentication (basic auth credentials) and authorization
# (:execute_openbolt permission) on every API endpoint. The unit tests
# pin the engine.rb permission map symbol-by-symbol; this suite pins
# the same wiring end-to-end against the live Foreman, catching
# regressions the unit tests can't (plugin not loaded, role not
# registered, before_action not running).
class ApiAuthnAuthzTest < ApiAcceptanceTestCase
  def test_no_credentials_returns401
    anonymous = Faraday.new(url: FOREMAN_API_URL,
      ssl: { verify: false },
      request: { timeout: 30 },
      headers: { 'Host' => FOREMAN_FQDN }) do |conn|
      conn.request :json
      conn.response :json, content_type: /\bjson$/
    end
    resp = anonymous.get('/api/v2/openbolt/jobs')
    assert_equal 401, resp.status, resp.body.inspect
  end

  def test_wrong_credentials_returns401
    wrong = build_client(ADMIN_USER, 'definitely-not-the-password')
    resp = wrong.get('/api/v2/openbolt/jobs')
    assert_equal 401, resp.status, resp.body.inspect
  end

  def test_unprivileged_user_is_forbidden_from_jobs
    with_unprivileged_user do |client|
      resp = client.get('/api/v2/openbolt/jobs')
      assert_equal 403, resp.status, resp.body.inspect
    end
  end

  def test_unprivileged_user_is_forbidden_from_tasks
    with_unprivileged_user do |client|
      resp = client.get("/api/v2/openbolt/smart_proxies/#{smart_proxy_id}/tasks")
      assert_equal 403, resp.status, resp.body.inspect
    end
  end

  def test_unprivileged_user_is_forbidden_from_reload_tasks
    with_unprivileged_user do |client|
      resp = client.post("/api/v2/openbolt/smart_proxies/#{smart_proxy_id}/tasks/reload")
      assert_equal 403, resp.status, resp.body.inspect
    end
  end

  def test_unprivileged_user_is_forbidden_from_task_options
    with_unprivileged_user do |client|
      resp = client.get("/api/v2/openbolt/smart_proxies/#{smart_proxy_id}/tasks/options")
      assert_equal 403, resp.status, resp.body.inspect
    end
  end

  def test_unprivileged_user_is_forbidden_from_launch_task
    with_unprivileged_user do |client|
      resp = client.post('/api/v2/openbolt/launch/task',
        smart_proxy_id: smart_proxy_id,
        task_name: 'acceptance::noop_task',
        targets: 'target1.example.com',
        parameters: {})
      assert_equal 403, resp.status, resp.body.inspect
    end
  end

  def test_unprivileged_user_is_forbidden_from_job_status
    # Seed a real job so the route resolves; the 403 should fire before
    # the action body looks up the TaskJob.
    job_id = launch_and_wait_for(task: 'acceptance::noop_task')

    with_unprivileged_user do |client|
      resp = client.get("/api/v2/openbolt/jobs/#{job_id}/status")
      assert_equal 403, resp.status, resp.body.inspect
    end
  end

  def test_unprivileged_user_is_forbidden_from_job_result
    job_id = launch_and_wait_for(task: 'acceptance::noop_task')

    with_unprivileged_user do |client|
      resp = client.get("/api/v2/openbolt/jobs/#{job_id}/result")
      assert_equal 403, resp.status, resp.body.inspect
    end
  end
end

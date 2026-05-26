# frozen_string_literal: true

require_relative '../../api_acceptance_helper'

# Tests the proxy-scoped read endpoints: GET /smart_proxies/:id/tasks,
# POST /smart_proxies/:id/tasks/reload, GET /smart_proxies/:id/tasks/options.
# These all need :execute_openbolt + :view_smart_proxies and take the
# smart_proxy_id in the URL path.
class ApiProxyTasksTest < ApiAcceptanceTestCase
  def test_tasks_lists_the_acceptance_fixture_tasks
    resp = @api.get("/api/v2/openbolt/smart_proxies/#{smart_proxy_id}/tasks")
    assert_equal 200, resp.status, resp.body.inspect

    task_names = resp.body.keys
    %w[acceptance::echo acceptance::noop_task acceptance::failing_task
       acceptance::complex_params].each do |expected|
      assert_includes task_names, expected,
        "expected proxy task list to include '#{expected}', got: #{task_names.inspect}"
    end
  end

  def test_tasks_returns_404_for_unknown_smart_proxy
    resp = @api.get('/api/v2/openbolt/smart_proxies/999999/tasks')
    assert_equal 404, resp.status, resp.body.inspect
    assert_match(/not found/i, error_message(resp.body).to_s)
  end

  def test_reload_tasks_returns_reloaded_list
    resp = @api.post("/api/v2/openbolt/smart_proxies/#{smart_proxy_id}/tasks/reload")
    assert_equal 200, resp.status, resp.body.inspect
    assert_includes resp.body.keys, 'acceptance::echo'
  end

  def test_reload_tasks_returns_404_for_unknown_smart_proxy
    resp = @api.post('/api/v2/openbolt/smart_proxies/999999/tasks/reload')
    assert_equal 404, resp.status, resp.body.inspect
    assert_match(/not found/i, error_message(resp.body).to_s)
  end

  def test_task_options_returns_options_with_setting_defaults_merged
    # acceptance:up sets these three Foreman settings before tests run.
    # The endpoint should reflect them as the 'default' for each option.
    resp = @api.get("/api/v2/openbolt/smart_proxies/#{smart_proxy_id}/tasks/options")
    assert_equal 200, resp.status, resp.body.inspect

    assert_equal 'openbolt', resp.body.dig('user', 'default')
    assert_equal '/opt/foreman-proxy/.ssh/id_rsa', resp.body.dig('private-key', 'default')
    assert_equal false, resp.body.dig('host-key-check', 'default')
  end

  def test_task_options_returns_404_for_unknown_smart_proxy
    resp = @api.get('/api/v2/openbolt/smart_proxies/999999/tasks/options')
    assert_equal 404, resp.status, resp.body.inspect
  end
end

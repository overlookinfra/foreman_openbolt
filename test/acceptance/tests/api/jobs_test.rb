# frozen_string_literal: true

require_relative '../../api_acceptance_helper'

# Tests the kind-agnostic job-read endpoints: GET /jobs (list), GET
# /jobs/:job_id/status, GET /jobs/:job_id/result. These read from
# Foreman's DB; the proxy is not in the path.
class ApiJobsTest < ApiAcceptanceTestCase
  def test_jobs_returns_paginated_envelope_with_kind
    # Seed one job so the assertions below have a row to inspect.
    job_id = launch_and_wait_for(task: 'acceptance::noop_task')

    resp = @api.get('/api/v2/openbolt/jobs')
    assert_equal 200, resp.status, resp.body.inspect

    assert resp.body.key?('total'), 'expected total key in pagination envelope'
    assert resp.body.key?('page'), 'expected page key in pagination envelope'
    assert resp.body.key?('per_page'), 'expected per_page key in pagination envelope'

    seeded = resp.body['results'].find { |row| row['job_id'] == job_id }
    flunk "newly launched job #{job_id} not present in /jobs response" unless seeded
    assert_equal 'task', seeded['kind']
    assert_includes %w[success failure exception invalid], seeded['status']
    assert seeded['smart_proxy'].is_a?(Hash), "expected smart_proxy hash, got: #{seeded['smart_proxy'].inspect}"
  end

  def test_jobs_per_page_all_returns_every_row_in_one_page
    # Trigger one more job to guarantee at least 1 row.
    launch_and_wait_for(task: 'acceptance::noop_task')

    resp = @api.get('/api/v2/openbolt/jobs', per_page: 'all')
    assert_equal 200, resp.status, resp.body.inspect
    assert_equal resp.body['total'], resp.body['results'].length,
      'per_page=all should return every recorded job in one page'
  end

  def test_jobs_caps_per_page_at100
    resp = @api.get('/api/v2/openbolt/jobs', per_page: 500)
    assert_equal 200, resp.status, resp.body.inspect
    assert_equal 100, resp.body['per_page']
  end

  def test_status_returns_job_status_payload_with_kind
    job_id = launch_and_wait_for(task: 'acceptance::noop_task')

    resp = @api.get("/api/v2/openbolt/jobs/#{job_id}/status")
    assert_equal 200, resp.status, resp.body.inspect
    assert_equal 'task', resp.body['kind']
    assert_includes %w[success failure exception invalid], resp.body['status']
    assert_equal 'acceptance::noop_task', resp.body['name']
    assert resp.body['smart_proxy'].is_a?(Hash)
    assert_equal smart_proxy_id, resp.body.dig('smart_proxy', 'id')
  end

  def test_status_returns_404_for_unknown_job_id
    resp = @api.get('/api/v2/openbolt/jobs/nonexistent-job-id/status')
    assert_equal 404, resp.status, resp.body.inspect
    # error_message handles both 404 envelope shapes Foreman produces
    # (nested via error_layout, flat via not_found(string)).
    assert_match(/not found/i, error_message(resp.body).to_s)
  end

  def test_result_returns_command_value_log_for_completed_job
    job_id = launch_and_wait_for(task: 'acceptance::noop_task')

    resp = @api.get("/api/v2/openbolt/jobs/#{job_id}/result")
    assert_equal 200, resp.status, resp.body.inspect
    assert_equal 'task', resp.body['kind']
    assert_equal 'success', resp.body['status'], resp.body.inspect
    assert resp.body.key?('command'), 'expected command key in result payload'
    assert resp.body.key?('value'), 'expected value key in result payload'
    assert resp.body.key?('log'), 'expected log key in result payload'
    assert_match(/acceptance::noop_task/, resp.body['command'].to_s)
  end

  def test_result_returns_404_for_unknown_job_id
    resp = @api.get('/api/v2/openbolt/jobs/nonexistent-job-id/result')
    assert_equal 404, resp.status, resp.body.inspect
    assert_match(/not found/i, error_message(resp.body).to_s)
  end
end

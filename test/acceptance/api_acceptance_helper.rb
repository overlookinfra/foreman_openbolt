# frozen_string_literal: true

require 'faraday'
require 'json'
require 'test/unit'

# Base class for API-driven acceptance tests. Sibling to AcceptanceTestCase
# (which drives the UI via Capybara/Selenium). API tests hit the Foreman
# API directly via Faraday from the host process, no browser involved.
#
# The Foreman container publishes port 443. Default to https://localhost
# rather than the FOREMAN_URL ('https://foreman') used by the UI tests,
# since 'foreman' only resolves inside the docker network. The Host
# header is set to foreman.example.com so Foreman accepts the request
# under its configured hostname.
class ApiAcceptanceTestCase < Test::Unit::TestCase
  FOREMAN_API_URL = ENV.fetch('FOREMAN_API_URL', 'https://localhost')
  FOREMAN_FQDN = 'foreman.example.com'
  ADMIN_USER = ENV.fetch('FOREMAN_USER', 'admin')
  ADMIN_PASS = ENV.fetch('FOREMAN_PASS', 'changeme')

  TERMINAL_STATUSES = %w[success failure exception invalid].freeze

  def setup
    @api = build_client(ADMIN_USER, ADMIN_PASS)
    @created_user_ids = []
  end

  def teardown
    @created_user_ids.each do |user_id|
      @api.delete("/api/v2/users/#{user_id}")
    rescue StandardError
      # Best effort. Test failures shouldn't be masked by teardown noise.
    end
  end

  # Builds a Faraday client authenticated as the given user. Used by
  # with_user to swap auth mid-test, and by setup for the admin client.
  # Content-Type is set as a default header so empty-body POSTs (like
  # reload_tasks) still send it. Foreman's check_media_type before_action
  # 415s POST/PUT requests with no Content-Type.
  def build_client(user, pass)
    Faraday.new(url: FOREMAN_API_URL,
      ssl: { verify: false },
      request: { timeout: 30 },
      headers: {
        'Host' => FOREMAN_FQDN,
        'Content-Type' => 'application/json',
      }) do |conn|
      conn.request :authorization, :basic, user, pass
      conn.request :json
      conn.response :json, content_type: /\bjson$/
    end
  end

  # Foreman's 404 envelope has two shapes depending on which path produced
  # it: nested {error: {message: ...}} (from render_error templates wrapped
  # via api/v2/layouts/error_layout, which our render_json_error also
  # produces) and flat {message: ...} (from not_found(string), which calls
  # render :json directly with no layout). Pull the message from either so
  # acceptance assertions don't have to know which path fired.
  def error_message(body)
    return nil unless body.is_a?(Hash)
    body.dig('error', 'message') || body['message']
  end

  # Memoized lookup of the smart proxy created during acceptance:up. The
  # DB id is not stable across rebuilds, so always resolve by name.
  def smart_proxy_id
    @smart_proxy_id ||= begin
      resp = @api.get('/api/v2/smart_proxies', search: "name=#{FOREMAN_FQDN}")
      id = resp.body.dig('results', 0, 'id')
      flunk "could not find smart proxy '#{FOREMAN_FQDN}' (status #{resp.status}): #{resp.body.inspect}" unless id
      id
    end
  end

  # POSTs /launch/task, polls /jobs/:job_id/status until the status is
  # terminal (one of success/failure/exception/invalid), then returns
  # the job_id. Tests fetch the result separately so they can assert on
  # both status and result fields without one helper doing too much.
  def launch_and_wait_for(task:, params: {}, targets: 'target1.example.com', timeout: 120)
    launch_resp = @api.post('/api/v2/openbolt/launch/task',
      smart_proxy_id: smart_proxy_id,
      task_name: task,
      targets: targets,
      parameters: params,
      options: { 'host-key-check' => false, 'user' => 'openbolt', 'private-key' => '/opt/foreman-proxy/.ssh/id_rsa' })
    assert_equal 201, launch_resp.status,
      "launch_task failed (#{launch_resp.status}): #{launch_resp.body.inspect}"
    job_id = launch_resp.body['job_id']
    flunk "launch_task returned no job_id: #{launch_resp.body.inspect}" unless job_id

    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    loop do
      status_resp = @api.get("/api/v2/openbolt/jobs/#{job_id}/status")
      assert_equal 200, status_resp.status,
        "status poll failed (#{status_resp.status}): #{status_resp.body.inspect}"
      status = status_resp.body['status']
      return job_id if TERMINAL_STATUSES.include?(status)
      flunk "timed out after #{timeout}s waiting for job #{job_id} (last status: #{status})" if
        Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      sleep 2
    end
  end

  # Creates a fresh Foreman user with no roles (so no permissions), yields
  # a Faraday client authenticated as that user, then deletes the user on
  # block exit. Used by authn/authz tests to drive endpoints as someone
  # without :execute_openbolt without polluting the global admin.
  def with_unprivileged_user
    login = "acc_unpriv_#{Process.pid}_#{rand(1_000_000)}"
    password = 'TempPass1!'
    resp = @api.post('/api/v2/users',
      user: {
        login: login,
        password: password,
        firstname: 'Acc',
        lastname: 'Unpriv',
        mail: "#{login}@example.com",
        auth_source_id: 1,
        admin: false,
        roles: [],
      })
    assert_equal 201, resp.status,
      "user creation failed (#{resp.status}): #{resp.body.inspect}"
    user_id = resp.body['id']
    @created_user_ids << user_id
    yield build_client(login, password)
  end
end

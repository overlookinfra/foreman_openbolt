# frozen_string_literal: true

require 'faraday'
require 'json'
require 'test/unit'

# Base class for API-driven acceptance tests. Unlike AcceptanceTestCase's
# Capybara suite, these hit the Foreman API from the host via Faraday.
# Defaults to https://localhost with the Host header set to the Foreman FQDN.
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
      # Best effort, not a big deal if something fails
    end
  end

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

  # Foreman 404s are either a nested {error: {message: ...}} body or a
  # flat {message: ...} body.
  def error_message(body)
    return nil unless body.is_a?(Hash)
    body.dig('error', 'message') || body['message']
  end

  # The proxy id is not stable across rebuilds, so resolve by name.
  def smart_proxy_id
    @smart_proxy_id ||= begin
      resp = @api.get('/api/v2/smart_proxies', search: "name=#{FOREMAN_FQDN}")
      id = resp.body.dig('results', 0, 'id')
      flunk "Could not find smart proxy '#{FOREMAN_FQDN}' (status #{resp.status}): #{resp.body.inspect}" unless id
      id
    end
  end

  # Launches the task and polls until the status is terminal. Returns the job_id.
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

  # Yields a client for a fresh role-less user, which is deleted in teardown.
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

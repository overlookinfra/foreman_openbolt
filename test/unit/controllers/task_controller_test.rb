# frozen_string_literal: true

require 'test_plugin_helper'

class TaskControllerTest < ActionController::TestCase
  tests ForemanOpenbolt::TaskController

  setup do
    @routes = ForemanOpenbolt::Engine.routes
    @proxy = FactoryBot.create(:smart_proxy)
    @session = set_session_user
    WebMock.reset!
  end

  teardown do
    WebMock.reset!
  end

  context 'fetch_tasks' do
    test 'returns tasks from proxy as JSON' do
      tasks = { 'mymod::install' => { 'description' => 'Install a package' } }
      stub_request(:get, "#{@proxy.url}/openbolt/tasks")
        .to_return(status: 200, body: tasks.to_json, headers: { 'Content-Type' => 'application/json' })

      get :fetch_tasks, params: { proxy_id: @proxy.id }, session: @session
      assert_response :success
      assert_equal tasks, JSON.parse(response.body)
    end

    test 'returns error when proxy_id is missing' do
      get :fetch_tasks, session: @session
      assert_response :bad_request
      body = JSON.parse(response.body)
      assert_match(/Smart Proxy ID is required/, body['error'])
    end

    test 'returns error when proxy not found' do
      get :fetch_tasks, params: { proxy_id: -1 }, session: @session
      assert_response :not_found
    end

    test 'returns internal_server_error when proxy is unreachable' do
      stub_request(:get, "#{@proxy.url}/openbolt/tasks").to_timeout

      get :fetch_tasks, params: { proxy_id: @proxy.id }, session: @session
      assert_response :internal_server_error
    end
  end

  context 'reload_tasks' do
    test 'returns reloaded tasks from proxy' do
      tasks = { 'new::task' => {} }
      stub_request(:get, "#{@proxy.url}/openbolt/tasks/reload")
        .to_return(status: 200, body: tasks.to_json, headers: { 'Content-Type' => 'application/json' })

      get :reload_tasks, params: { proxy_id: @proxy.id }, session: @session
      assert_response :success
      assert_equal tasks, JSON.parse(response.body)
    end
  end

  context 'launch_task' do
    setup do
      @tasks = { 'mymod::install' => { 'description' => 'Install a package' } }
      stub_request(:get, "#{@proxy.url}/openbolt/tasks")
        .to_return(status: 200, body: @tasks.to_json, headers: { 'Content-Type' => 'application/json' })
      stub_request(:post, "#{@proxy.url}/openbolt/launch/task")
        .to_return(status: 200, body: { 'id' => 'launched-job-1' }.to_json,
          headers: { 'Content-Type' => 'application/json' })
      ForemanTasks.stubs(:async_task)
    end

    test 'launches task and returns job_id' do
      post :launch_task, params: {
        proxy_id: @proxy.id,
        task_name: 'mymod::install',
        targets: 'host1.example.com',
        params: { 'name' => 'nginx' },
        options: { 'transport' => 'ssh' },
      }, session: @session

      assert_response :success
      body = JSON.parse(response.body)
      assert_equal 'launched-job-1', body['job_id']
    end

    test 'schedules polling after creating task' do
      ForemanTasks.expects(:async_task).with(
        Actions::ForemanOpenbolt::PollTaskStatus,
        'launched-job-1',
        @proxy.id
      )

      post :launch_task, params: {
        proxy_id: @proxy.id,
        task_name: 'mymod::install',
        targets: 'host1.example.com',
      }, session: @session

      assert_response :success
    end

    test 'creates a TaskJob record' do
      assert_difference('ForemanOpenbolt::TaskJob.count', 1) do
        post :launch_task, params: {
          proxy_id: @proxy.id,
          task_name: 'mymod::install',
          targets: 'host1.example.com,host2.example.com',
        }, session: @session
      end

      job = ForemanOpenbolt::TaskJob.last
      assert_equal 'mymod::install', job.task_name
      assert_equal %w[host1.example.com host2.example.com], job.targets
      assert_equal 'pending', job.status
    end

    test 'returns error when task_name is missing' do
      post :launch_task, params: { proxy_id: @proxy.id, targets: 'host1' }, session: @session
      assert_response :bad_request
      assert_match(/task_name/, JSON.parse(response.body)['error'])
    end

    test 'returns error when targets is missing' do
      post :launch_task, params: { proxy_id: @proxy.id, task_name: 'test::task' }, session: @session
      assert_response :bad_request
      assert_match(/targets/, JSON.parse(response.body)['error'])
    end

    test 'returns error when proxy returns error in response' do
      stub_request(:post, "#{@proxy.url}/openbolt/launch/task")
        .to_return(status: 200, body: { 'error' => 'Task not found' }.to_json,
          headers: { 'Content-Type' => 'application/json' })

      post :launch_task, params: {
        proxy_id: @proxy.id,
        task_name: 'missing::task',
        targets: 'host1',
      }, session: @session
      assert_response :bad_request
      assert_match(/Task execution failed/, JSON.parse(response.body)['error'])
    end

    test 'returns bad_gateway when proxy returns invalid JSON' do
      stub_request(:post, "#{@proxy.url}/openbolt/launch/task")
        .to_return(status: 200, body: 'not valid json',
          headers: { 'Content-Type' => 'application/json' })

      post :launch_task, params: {
        proxy_id: @proxy.id,
        task_name: 'mymod::install',
        targets: 'host1',
      }, session: @session
      assert_response :bad_gateway
      assert_match(/Smart Proxy error/, JSON.parse(response.body)['error'])
    end

    test 'returns error when proxy returns no job ID' do
      stub_request(:post, "#{@proxy.url}/openbolt/launch/task")
        .to_return(status: 200, body: { 'status' => 'ok' }.to_json,
          headers: { 'Content-Type' => 'application/json' })

      post :launch_task, params: {
        proxy_id: @proxy.id,
        task_name: 'test::task',
        targets: 'host1',
      }, session: @session
      assert_response :bad_request
      assert_match(/No job ID returned/, JSON.parse(response.body)['error'])
    end
  end

  context 'job_status' do
    test 'returns serialized task job' do
      job = FactoryBot.create(:task_job, :running, smart_proxy: @proxy)

      get :job_status, params: { job_id: job.job_id }, session: @session
      assert_response :success

      body = JSON.parse(response.body)
      assert_equal 'running', body['status']
      assert_equal job.task_name, body['task_name']
      assert_equal job.targets, body['targets']
      assert_equal @proxy.id, body['smart_proxy']['id']
      assert_equal @proxy.name, body['smart_proxy']['name']
    end

    test 'returns error when job_id is missing' do
      get :job_status, session: @session
      assert_response :bad_request
    end

    test 'returns not_found when job does not exist' do
      get :job_status, params: { job_id: 'nonexistent' }, session: @session
      assert_response :not_found
    end
  end

  context 'job_result' do
    test 'returns result and log for completed job' do
      ForemanTasks.stubs(:async_task)
      job = FactoryBot.create(:task_job, :success, smart_proxy: @proxy)

      get :job_result, params: { job_id: job.job_id }, session: @session
      assert_response :success

      body = JSON.parse(response.body)
      assert_equal 'success', body['status']
      assert_equal job.result, body['value']
      assert_equal job.log, body['log']
      assert_equal job.command, body['command']
    end

    test 'returns not_found when job does not exist' do
      get :job_result, params: { job_id: 'nonexistent' }, session: @session
      assert_response :not_found
    end
  end

  context 'launch_task with encrypted options' do
    setup do
      @tasks = { 'mymod::install' => { 'description' => 'Install a package' } }
      stub_request(:get, "#{@proxy.url}/openbolt/tasks")
        .to_return(status: 200, body: @tasks.to_json, headers: { 'Content-Type' => 'application/json' })
      stub_request(:post, "#{@proxy.url}/openbolt/launch/task")
        .to_return(status: 200, body: { 'id' => 'encrypted-job-1' }.to_json,
          headers: { 'Content-Type' => 'application/json' })
      ForemanTasks.stubs(:async_task)
    end

    test 'sends real encrypted value to proxy and scrubs it in database' do
      Setting['openbolt_password'] = 'real-secret-password'

      post :launch_task, params: {
        proxy_id: @proxy.id,
        task_name: 'mymod::install',
        targets: 'host1.example.com',
        options: { 'password' => '[Use saved encrypted default]', 'transport' => 'ssh' },
      }, session: @session

      assert_response :success

      assert_requested(:post, "#{@proxy.url}/openbolt/launch/task") do |req|
        sent_body = JSON.parse(req.body)
        sent_body['options']['password'] == 'real-secret-password'
      end

      job = ForemanOpenbolt::TaskJob.find_by(job_id: 'encrypted-job-1')
      assert_equal '*****', job.openbolt_options['password']
      assert_equal 'ssh', job.openbolt_options['transport']
    end

    test 'returns error when encrypted placeholder used for nonexistent setting' do
      post :launch_task, params: {
        proxy_id: @proxy.id,
        task_name: 'mymod::install',
        targets: 'host1.example.com',
        options: { 'nonexistent-option' => '[Use saved encrypted default]' },
      }, session: @session

      assert_response :bad_request
      assert_match(/No saved value for encrypted option/, JSON.parse(response.body)['error'])
    end

    test 'passes non-encrypted options through unchanged' do
      post :launch_task, params: {
        proxy_id: @proxy.id,
        task_name: 'mymod::install',
        targets: 'host1.example.com',
        options: { 'transport' => 'ssh', 'user' => 'admin' },
      }, session: @session

      assert_response :success
      job = ForemanOpenbolt::TaskJob.find_by(job_id: 'encrypted-job-1')
      assert_equal 'ssh', job.openbolt_options['transport']
      assert_equal 'admin', job.openbolt_options['user']
    end
  end

  context 'fetch_openbolt_options with settings defaults' do
    test 'merges Foreman setting defaults into proxy options' do
      Setting['openbolt_transport'] = 'winrm'
      Setting['openbolt_user'] = 'admin'

      proxy_options = {
        'transport' => { 'type' => %w[ssh winrm] },
        'user' => { 'type' => 'string' },
        'verbose' => { 'type' => 'boolean' },
      }
      stub_request(:get, "#{@proxy.url}/openbolt/tasks/options")
        .to_return(status: 200, body: proxy_options.to_json, headers: { 'Content-Type' => 'application/json' })

      get :fetch_openbolt_options, params: { proxy_id: @proxy.id }, session: @session
      assert_response :success

      body = JSON.parse(response.body)
      assert_equal 'winrm', body['transport']['default']
      assert_equal 'admin', body['user']['default']
      assert_equal false, body['verbose']['default']
    end

    test 'shows encrypted placeholder instead of real value for encrypted settings' do
      Setting['openbolt_password'] = 'secret-value'

      proxy_options = {
        'password' => { 'type' => 'string', 'sensitive' => true },
      }
      stub_request(:get, "#{@proxy.url}/openbolt/tasks/options")
        .to_return(status: 200, body: proxy_options.to_json, headers: { 'Content-Type' => 'application/json' })

      get :fetch_openbolt_options, params: { proxy_id: @proxy.id }, session: @session
      assert_response :success

      body = JSON.parse(response.body)
      assert_equal '[Use saved encrypted default]', body['password']['default']
    end
  end

  context 'fetch_openbolt_options with Choria settings defaults' do
    # Mirrors the real GET /openbolt/tasks/options response for Choria
    # (see smart_proxy_openbolt/lib/smart_proxy_openbolt/main.rb OPENBOLT_OPTIONS).
    def self.choria_proxy_options
      {
        'choria-task-agent' => { 'type' => %w[bolt_tasks shell], 'transport' => ['choria'], 'sensitive' => false },
        'choria-config-file' => { 'type' => 'string', 'transport' => ['choria'], 'sensitive' => false },
        'choria-mcollective-certname' => { 'type' => 'string', 'transport' => ['choria'], 'sensitive' => false },
        'choria-ssl-ca' => { 'type' => 'string', 'transport' => ['choria'], 'sensitive' => false },
        'choria-ssl-cert' => { 'type' => 'string', 'transport' => ['choria'], 'sensitive' => false },
        'choria-ssl-key' => { 'type' => 'string', 'transport' => ['choria'], 'sensitive' => false },
        'choria-collective' => { 'type' => 'string', 'transport' => ['choria'], 'sensitive' => false },
        'choria-puppet-environment' => { 'type' => 'string', 'transport' => ['choria'], 'sensitive' => false },
        'choria-rpc-timeout' => { 'type' => 'string', 'transport' => ['choria'], 'sensitive' => false },
        'choria-task-timeout' => { 'type' => 'string', 'transport' => ['choria'], 'sensitive' => false },
        'choria-command-timeout' => { 'type' => 'string', 'transport' => ['choria'], 'sensitive' => false },
        'choria-brokers' => { 'type' => 'string', 'transport' => ['choria'], 'sensitive' => false },
        'choria-broker-timeout' => { 'type' => 'string', 'transport' => ['choria'], 'sensitive' => false },
      }
    end

    test 'merges all Choria setting values into their option defaults' do
      Setting['openbolt_choria-task-agent'] = 'shell'
      Setting['openbolt_choria-config-file'] = '/etc/choria/client.conf'
      Setting['openbolt_choria-mcollective-certname'] = 'primary.example.com'
      Setting['openbolt_choria-ssl-ca'] = '/etc/choria/ca.pem'
      Setting['openbolt_choria-ssl-cert'] = '/etc/choria/client.pem'
      Setting['openbolt_choria-ssl-key'] = '/etc/choria/client.key'
      Setting['openbolt_choria-collective'] = 'mcollective'
      Setting['openbolt_choria-puppet-environment'] = 'production'
      Setting['openbolt_choria-rpc-timeout'] = 60
      Setting['openbolt_choria-task-timeout'] = 300
      Setting['openbolt_choria-command-timeout'] = 120
      Setting['openbolt_choria-brokers'] = 'broker.example.com:4222'
      Setting['openbolt_choria-broker-timeout'] = 10

      stub_request(:get, "#{@proxy.url}/openbolt/tasks/options")
        .to_return(status: 200, body: self.class.choria_proxy_options.to_json,
          headers: { 'Content-Type' => 'application/json' })

      get :fetch_openbolt_options, params: { proxy_id: @proxy.id }, session: @session
      assert_response :success

      body = JSON.parse(response.body)
      assert_equal 'shell', body['choria-task-agent']['default']
      assert_equal '/etc/choria/client.conf', body['choria-config-file']['default']
      assert_equal 'primary.example.com', body['choria-mcollective-certname']['default']
      assert_equal '/etc/choria/ca.pem', body['choria-ssl-ca']['default']
      assert_equal '/etc/choria/client.pem', body['choria-ssl-cert']['default']
      assert_equal '/etc/choria/client.key', body['choria-ssl-key']['default']
      assert_equal 'mcollective', body['choria-collective']['default']
      assert_equal 'production', body['choria-puppet-environment']['default']
      assert_equal 60, body['choria-rpc-timeout']['default']
      assert_equal 300, body['choria-task-timeout']['default']
      assert_equal 120, body['choria-command-timeout']['default']
      assert_equal 'broker.example.com:4222', body['choria-brokers']['default']
      assert_equal 10, body['choria-broker-timeout']['default']
    end

    test 'omits nil-default settings and keeps real defaults when Choria settings are not configured' do
      stub_request(:get, "#{@proxy.url}/openbolt/tasks/options")
        .to_return(status: 200, body: self.class.choria_proxy_options.to_json,
          headers: { 'Content-Type' => 'application/json' })

      get :fetch_openbolt_options, params: { proxy_id: @proxy.id }, session: @session
      assert_response :success

      body = JSON.parse(response.body)
      assert_equal 'bolt_tasks', body['choria-task-agent']['default']
      assert_not body['choria-config-file'].key?('default')
      assert_not body['choria-mcollective-certname'].key?('default')
      assert_not body['choria-ssl-key'].key?('default')
      assert_not body['choria-brokers'].key?('default')
      assert_not body['choria-broker-timeout'].key?('default')
    end
  end

  context 'fetch_task_history' do
    test 'returns paginated task history' do
      3.times { FactoryBot.create(:task_job, smart_proxy: @proxy) }

      get :fetch_task_history, params: { page: 1, per_page: 2 }, session: @session
      assert_response :success

      body = JSON.parse(response.body)
      assert_equal 2, body['results'].length
      assert_equal 3, body['total']
      assert_equal 1, body['page']
      assert_equal 2, body['per_page']
    end

    test 'caps per_page at 100' do
      get :fetch_task_history, params: { per_page: 200 }, session: @session
      assert_response :success

      body = JSON.parse(response.body)
      assert_equal 100, body['per_page']
    end

    test 'defaults per_page to 20' do
      get :fetch_task_history, session: @session
      assert_response :success

      body = JSON.parse(response.body)
      assert_equal 20, body['per_page']
    end
  end
end

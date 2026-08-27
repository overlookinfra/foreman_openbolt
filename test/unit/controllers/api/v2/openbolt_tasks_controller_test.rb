# frozen_string_literal: true

require 'test_plugin_helper'

module Api
  module V2
    class OpenboltTasksControllerTest < ActionController::TestCase
      setup do
        @proxy = FactoryBot.create(:smart_proxy)
        @session = set_session_user
        WebMock.reset!
      end

      teardown do
        WebMock.reset!
      end

      context 'tasks' do
        test 'returns tasks list from the proxy as JSON' do
          tasks = { 'mymod::install' => { 'description' => 'Install a package' } }
          stub_request(:get, "#{@proxy.url}/openbolt/tasks")
            .to_return(status: 200, body: tasks.to_json, headers: { 'Content-Type' => 'application/json' })

          get :tasks, params: { smart_proxy_id: @proxy.id }, session: @session
          assert_response :success
          assert_equal tasks, JSON.parse(response.body)
        end

        test 'returns not_found when smart_proxy does not exist' do
          get :tasks, params: { smart_proxy_id: -1 }, session: @session
          assert_response :not_found
          assert_match(/not found/, JSON.parse(response.body)['error']['message'])
        end

        test 'returns bad_gateway when proxy returns invalid JSON' do
          stub_request(:get, "#{@proxy.url}/openbolt/tasks")
            .to_return(status: 200, body: 'not valid json',
              headers: { 'Content-Type' => 'application/json' })

          get :tasks, params: { smart_proxy_id: @proxy.id }, session: @session
          assert_response :bad_gateway
        end

        test 'returns bad_gateway when ProxyAPI::Openbolt.new raises' do
          ::ProxyAPI::Openbolt.expects(:new).raises(StandardError, 'ssl setup failed')

          get :tasks, params: { smart_proxy_id: @proxy.id }, session: @session
          assert_response :bad_gateway
          assert_match(/Failed to connect to Smart Proxy/,
            JSON.parse(response.body)['error']['message'])
        end
      end

      context 'reload_tasks' do
        test 'returns reloaded task list' do
          tasks = { 'new::task' => {} }
          stub_request(:get, "#{@proxy.url}/openbolt/tasks/reload")
            .to_return(status: 200, body: tasks.to_json, headers: { 'Content-Type' => 'application/json' })

          post :reload_tasks, params: { smart_proxy_id: @proxy.id }, session: @session
          assert_response :success
          assert_equal tasks, JSON.parse(response.body)
        end
      end

      context 'task_options' do
        test 'returns options with Foreman setting defaults merged in' do
          Setting['openbolt_transport'] = 'winrm'

          proxy_options = {
            'transport' => { 'type' => %w[ssh winrm] },
            'verbose' => { 'type' => 'boolean' },
          }
          stub_request(:get, "#{@proxy.url}/openbolt/tasks/options")
            .to_return(status: 200, body: proxy_options.to_json,
              headers: { 'Content-Type' => 'application/json' })

          get :task_options, params: { smart_proxy_id: @proxy.id }, session: @session
          assert_response :success
          body = JSON.parse(response.body)
          assert_equal 'winrm', body['transport']['default']
          assert_equal false, body['verbose']['default']
        end

        test 'shows encrypted placeholder instead of the saved secret value' do
          Setting['openbolt_password'] = 'real-secret-value'

          proxy_options = {
            'password' => { 'type' => 'string', 'sensitive' => true },
          }
          stub_request(:get, "#{@proxy.url}/openbolt/tasks/options")
            .to_return(status: 200, body: proxy_options.to_json,
              headers: { 'Content-Type' => 'application/json' })

          get :task_options, params: { smart_proxy_id: @proxy.id }, session: @session
          assert_response :success
          body = JSON.parse(response.body)
          assert_equal '[Use saved encrypted default]', body['password']['default']
          assert_no_match(/real-secret-value/, response.body)
        end
      end

      context 'launch_task' do
        setup do
          @tasks = { 'mymod::install' => { 'description' => 'Install a package' } }
          stub_request(:get, "#{@proxy.url}/openbolt/tasks")
            .to_return(status: 200, body: @tasks.to_json, headers: { 'Content-Type' => 'application/json' })
          stub_request(:post, "#{@proxy.url}/openbolt/launch/task")
            .to_return(status: 200, body: { 'id' => 'api-job-1' }.to_json,
              headers: { 'Content-Type' => 'application/json' })
          ForemanTasks.stubs(:async_task)
        end

        test 'launches task and returns job_id with kind' do
          post :launch_task, params: {
            smart_proxy_id: @proxy.id,
            task_name: 'mymod::install',
            targets: 'host1.example.com',
          }, session: @session

          assert_response :success
          body = JSON.parse(response.body)
          assert_equal 'api-job-1', body['job_id']
          assert_equal 'task', body['kind']
        end

        test 'schedules polling after launch' do
          ForemanTasks.expects(:async_task).with(
            Actions::ForemanOpenbolt::PollTaskStatus,
            'api-job-1',
            @proxy.id
          )

          post :launch_task, params: {
            smart_proxy_id: @proxy.id,
            task_name: 'mymod::install',
            targets: 'host1.example.com',
          }, session: @session

          assert_response :success
        end

        test 'creates a TaskJob record' do
          assert_difference('ForemanOpenbolt::TaskJob.count', 1) do
            post :launch_task, params: {
              smart_proxy_id: @proxy.id,
              task_name: 'mymod::install',
              targets: 'host1.example.com,host2.example.com',
            }, session: @session
          end
          job = ForemanOpenbolt::TaskJob.find_by(job_id: 'api-job-1')
          assert_equal 'mymod::install', job.task_name
          assert_equal %w[host1.example.com host2.example.com], job.targets
        end

        test 'returns bad_request when task_name and targets are missing' do
          post :launch_task, params: { smart_proxy_id: @proxy.id }, session: @session
          assert_response :bad_request
        end

        test 'returns bad_request and persists nothing when proxy returns error' do
          stub_request(:post, "#{@proxy.url}/openbolt/launch/task")
            .to_return(status: 200, body: { 'error' => 'Task not found' }.to_json,
              headers: { 'Content-Type' => 'application/json' })
          ForemanTasks.expects(:async_task).never

          assert_no_difference('ForemanOpenbolt::TaskJob.count') do
            post :launch_task, params: {
              smart_proxy_id: @proxy.id,
              task_name: 'missing::task',
              targets: 'host1',
            }, session: @session
          end
          assert_response :bad_request
        end

        test 'returns bad_request and persists nothing when proxy returns no job id' do
          stub_request(:post, "#{@proxy.url}/openbolt/launch/task")
            .to_return(status: 200, body: { 'status' => 'ok' }.to_json,
              headers: { 'Content-Type' => 'application/json' })
          ForemanTasks.expects(:async_task).never

          assert_no_difference('ForemanOpenbolt::TaskJob.count') do
            post :launch_task, params: {
              smart_proxy_id: @proxy.id,
              task_name: 'test::task',
              targets: 'host1',
            }, session: @session
          end
          assert_response :bad_request
        end

        test 'returns bad_request when smart_proxy_id is missing' do
          post :launch_task, params: { task_name: 'test::task', targets: 'host1' }, session: @session
          assert_response :bad_request
          body = JSON.parse(response.body)
          assert_kind_of Hash, body['error']
          assert_match(/Smart Proxy ID is required/, body['error']['message'])
        end

        test 'returns bad_request and persists nothing when encrypted placeholder is used for nonexistent setting' do
          ForemanTasks.expects(:async_task).never

          assert_no_difference('ForemanOpenbolt::TaskJob.count') do
            post :launch_task, params: {
              smart_proxy_id: @proxy.id,
              task_name: 'mymod::install',
              targets: 'host1.example.com',
              options: { 'nonexistent-option' => '[Use saved encrypted default]' },
            }, session: @session
          end
          assert_response :bad_request
          assert_match(/No saved value for encrypted option/,
            JSON.parse(response.body)['error']['message'])
        end

        test 'sends literal encrypted-option value to proxy but scrubs it in the database' do
          post :launch_task, params: {
            smart_proxy_id: @proxy.id,
            task_name: 'mymod::install',
            targets: 'host1.example.com',
            options: { 'password' => 'literal-typed-secret', 'transport' => 'ssh' },
          }, session: @session

          assert_response :success
          launch_url = "#{@proxy.url}/openbolt/launch/task"
          assert_requested(:post, launch_url) do |req|
            sent = JSON.parse(req.body)
            sent['options']['password'] == 'literal-typed-secret'
          end

          job = ForemanOpenbolt::TaskJob.find_by(job_id: 'api-job-1')
          assert_equal '*****', job.openbolt_options['password']
          assert_equal 'ssh', job.openbolt_options['transport']
        end

        test 'sends real encrypted value to proxy and scrubs it in the database' do
          Setting['openbolt_password'] = 'real-secret-password'

          post :launch_task, params: {
            smart_proxy_id: @proxy.id,
            task_name: 'mymod::install',
            targets: 'host1.example.com',
            options: { 'password' => '[Use saved encrypted default]', 'transport' => 'ssh' },
          }, session: @session

          assert_response :success
          launch_url = "#{@proxy.url}/openbolt/launch/task"
          assert_requested(:post, launch_url) do |req|
            sent = JSON.parse(req.body)
            sent['options']['password'] == 'real-secret-password' &&
              sent['options']['transport'] == 'ssh'
          end

          job = ForemanOpenbolt::TaskJob.find_by(job_id: 'api-job-1')
          assert_equal '*****', job.openbolt_options['password']
          assert_equal 'ssh', job.openbolt_options['transport']
        end

        test 'returns 500 and marks the row exception when async_task scheduling fails' do
          ForemanTasks.stubs(:async_task).raises(StandardError, 'Dynflow executor unavailable')

          post :launch_task, params: {
            smart_proxy_id: @proxy.id,
            task_name: 'mymod::install',
            targets: 'host1.example.com',
          }, session: @session

          assert_response :internal_server_error
          assert_match(/background polling could not be scheduled/,
            JSON.parse(response.body)['error']['message'])

          job = ForemanOpenbolt::TaskJob.find_by(job_id: 'api-job-1')
          assert_not_nil job, 'TaskJob row should be persisted even when polling scheduling fails'
          assert_equal 'exception', job.status
        end

        test 'logs the persisted status when the exception flip itself fails' do
          ForemanTasks.stubs(:async_task).raises(StandardError, 'Dynflow executor unavailable')
          ForemanOpenbolt::TaskJob.any_instance.stubs(:update!).raises(
            ActiveRecord::RecordInvalid.new(ForemanOpenbolt::TaskJob.new)
          )

          Foreman::Logging.stubs(:exception)
          Foreman::Logging.expects(:exception)
                          .with(regexp_matches(/Row will remain in 'pending' state/), anything)
                          .at_least_once

          post :launch_task, params: {
            smart_proxy_id: @proxy.id,
            task_name: 'mymod::install',
            targets: 'host1.example.com',
          }, session: @session

          assert_response :internal_server_error
          assert_match(/background polling could not be scheduled/,
            JSON.parse(response.body)['error']['message'])

          job = ForemanOpenbolt::TaskJob.find_by(job_id: 'api-job-1')
          assert_not_nil job, 'TaskJob row should still be persisted'
          assert_equal 'pending', job.status
        end

        test 'persists with empty description when metadata fetch fails with ProxyException' do
          tasks_url = "#{@proxy.url}/openbolt/tasks"
          ::ProxyAPI::Openbolt.any_instance.stubs(:tasks).raises(
            ::ProxyAPI::ProxyException.new(tasks_url, RuntimeError.new('boom'), 'proxy down post-launch')
          )

          post :launch_task, params: {
            smart_proxy_id: @proxy.id,
            task_name: 'mymod::install',
            targets: 'host1.example.com',
          }, session: @session

          assert_response :success
          job = ForemanOpenbolt::TaskJob.find_by(job_id: 'api-job-1')
          assert_not_nil job
          assert_equal '', job.task_description
          assert_equal 'pending', job.status
        end

        test 'persists with empty description when metadata fetch fails with transport error' do
          ::ProxyAPI::Openbolt.any_instance.stubs(:tasks).raises(Errno::ECONNREFUSED)

          post :launch_task, params: {
            smart_proxy_id: @proxy.id,
            task_name: 'mymod::install',
            targets: 'host1.example.com',
          }, session: @session

          assert_response :success
          job = ForemanOpenbolt::TaskJob.find_by(job_id: 'api-job-1')
          assert_not_nil job
          assert_equal '', job.task_description
          assert_equal 'pending', job.status
        end

        test 'returns 500 with the proxy job id when TaskJob persistence fails post-launch' do
          ForemanOpenbolt::TaskJob.stubs(:create_from_execution!)
                                  .raises(ActiveRecord::RecordInvalid.new(ForemanOpenbolt::TaskJob.new))

          post :launch_task, params: {
            smart_proxy_id: @proxy.id,
            task_name: 'mymod::install',
            targets: 'host1.example.com',
          }, session: @session

          assert_response :internal_server_error
          body = JSON.parse(response.body)
          assert_match(/api-job-1/, body['error']['message'])
          assert_match(/could not record/i, body['error']['message'])
        end

        test 'forwards parameters body field to the proxy' do
          post :launch_task, params: {
            smart_proxy_id: @proxy.id,
            task_name: 'mymod::install',
            targets: 'host1.example.com',
            parameters: { 'name' => 'nginx', 'version' => '1.21' },
          }, session: @session

          assert_response :success
          launch_url = "#{@proxy.url}/openbolt/launch/task"
          assert_requested(:post, launch_url) do |req|
            sent = JSON.parse(req.body)
            sent['parameters'] == { 'name' => 'nginx', 'version' => '1.21' }
          end

          job = ForemanOpenbolt::TaskJob.find_by(job_id: 'api-job-1')
          assert_equal({ 'name' => 'nginx', 'version' => '1.21' }, job.task_parameters)
        end
      end

      context 'authorization' do
        test 'forbids users without execute_openbolt permission' do
          reset_api_credentials
          unprivileged = FactoryBot.create(:user)
          User.current = unprivileged

          get :tasks, params: { smart_proxy_id: @proxy.id },
            session: set_session_user(unprivileged)
          assert_response :forbidden
        end

        test 'forbids unprivileged users from launching tasks' do
          reset_api_credentials
          unprivileged = FactoryBot.create(:user)
          User.current = unprivileged

          post :launch_task, params: {
            smart_proxy_id: @proxy.id,
            task_name: 'mymod::install',
            targets: 'host1.example.com',
          }, session: set_session_user(unprivileged)
          assert_response :forbidden
        end

        test 'allows users granted execute_openbolt via setup_user' do
          tasks_url = "#{@proxy.url}/openbolt/tasks"
          tasks = { 'mymod::install' => { 'description' => 'Install a package' } }
          stub_request(:get, tasks_url)
            .to_return(status: 200, body: tasks.to_json,
              headers: { 'Content-Type' => 'application/json' })
          reset_api_credentials
          granted = FactoryBot.create(:user)
          setup_user('execute', 'openbolt', nil, granted)
          setup_user('view', 'smart_proxies', nil, granted)
          User.current = granted

          get :tasks, params: { smart_proxy_id: @proxy.id },
            session: set_session_user(granted)
          assert_response :success
        end

        test 'forbids unprivileged users from fetching task options' do
          reset_api_credentials
          unprivileged = FactoryBot.create(:user)
          User.current = unprivileged

          get :task_options, params: { smart_proxy_id: @proxy.id },
            session: set_session_user(unprivileged)
          assert_response :forbidden
        end

        test 'forbids unprivileged users from reloading the task cache' do
          reset_api_credentials
          unprivileged = FactoryBot.create(:user)
          User.current = unprivileged

          post :reload_tasks, params: { smart_proxy_id: @proxy.id },
            session: set_session_user(unprivileged)
          assert_response :forbidden
        end
      end
    end
  end
end

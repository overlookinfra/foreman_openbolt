# frozen_string_literal: true

require 'test_plugin_helper'

module Api
  module V2
    class OpenboltControllerTest < ActionController::TestCase
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
          # Pin the custom_error envelope so a future revert to not_found(string),
          # which would silently emit {"message": ...} instead of
          # {"error": {"message": ...}}, fails this test.
          assert_match(/not found/, JSON.parse(response.body)['error']['message'])
        end

        test 'returns bad_gateway when proxy returns invalid JSON' do
          stub_request(:get, "#{@proxy.url}/openbolt/tasks")
            .to_return(status: 200, body: 'not valid json',
              headers: { 'Content-Type' => 'application/json' })

          get :tasks, params: { smart_proxy_id: @proxy.id }, session: @session
          assert_response :bad_gateway
        end

        # Pins the load_openbolt_api rescue in ForemanOpenbolt::Common. The
        # invalid-JSON test above exercises the rescue_from ProxyException on
        # the controller, since the action body raises after the API client
        # is already built. This test forces ProxyAPI::Openbolt.new itself
        # to raise (e.g. SSL setup failure via Foreman::WrappedException) so
        # the concern's rescue is what produces the 502.
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
          # Guards against the API leaking the real value for encrypted settings.
          # The loop that handles this is duplicated between the UI and API
          # controllers, so the UI test does not protect this path.
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
          # Setup stubs async_task. Assert it is NOT called for the failure path.
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
          # Also pins the nested {error: {message: ...}} envelope on the 400
          # path so a regression to the flat {error: "..."} shape fails here.
          # The proxy-scoped tasks/reload/options endpoints can't reach this
          # path because the route requires :smart_proxy_id in the URL. Only
          # launch_task takes it as a body param.
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
          # Foreman's API error layout wraps the custom_error template's
          # {"message": ...} in {"error": ...}, so the message lives under error.message.
          assert_match(/No saved value for encrypted option/,
            JSON.parse(response.body)['error']['message'])
        end

        test 'sends literal encrypted-option value to proxy but scrubs it in the database' do
          # The placeholder path is tested below. This covers the other branch
          # of scrub_options_for_storage where the user submits the literal
          # value directly. The scrubber redacts by setting-key, not by sentinel,
          # so both paths must redact at the storage boundary while the proxy
          # receives the real value.
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
          # The proxy has accepted the task at this point. Only the Foreman-side
          # poller could not be scheduled. The TaskJob row should be persisted
          # so the proxy job isn't completely invisible, but its status should
          # reflect that polling won't happen.
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
          # When async_task scheduling fails AND the follow-up update! fails,
          # the inner-rescue log message must report the on-disk status
          # ('pending', set by create_from_execution!), not the in-memory
          # 'exception' that assign_attributes wrote before save! raised.
          # If the previous_status capture in tasks.rb regresses, the log
          # would report 'exception' while the DB still holds 'pending',
          # misleading the operator about what to fix manually.
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

        test 'persists with empty description when metadata fetch fails with raw transport error' do
          # ProxyAPI::Openbolt now wraps transport errors as ProxyException,
          # but the metadata begin/rescue must still tolerate raw
          # RestClient/Errno/Socket exceptions in case the wrapping is ever
          # bypassed. A transient post-launch hiccup must not kill the
          # live proxy job.
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
          # The proxy has accepted the task but Foreman cannot record it.
          # The error message must include the proxy job id so an operator
          # can correlate the orphaned proxy task.
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

      context 'jobs' do
        test 'returns empty results with pagination envelope when no jobs exist' do
          get :jobs, session: @session
          assert_response :success
          body = JSON.parse(response.body)
          assert_equal [], body['results']
          assert_equal 0, body['total']
          assert_equal 1, body['page']
        end

        test 'returns paginated results with kind on each entry' do
          3.times { FactoryBot.create(:task_job, smart_proxy: @proxy) }

          get :jobs, params: { page: 1, per_page: 2 }, session: @session
          assert_response :success
          body = JSON.parse(response.body)
          assert_equal 2, body['results'].length
          assert_equal 3, body['total']
          assert_equal 1, body['page']
          assert_equal 2, body['per_page']
          assert(body['results'].all? { |row| row['kind'] == 'task' })

          # Pin the fields task_job_status produces. The helper is
          # shared between this jobs endpoint and the UI's task-history view.
          # Without per-field assertions a future refactor could drop a field
          # (e.g. job_id, smart_proxy.id) and only the React UI would notice.
          row = body['results'].first
          %w[job_id task_name task_description task_parameters targets status
             submitted_at completed_at duration].each do |field|
            assert row.key?(field), "expected results[0] to contain '#{field}'"
          end
          assert_equal @proxy.id, row['smart_proxy']['id']
          assert_equal @proxy.name, row['smart_proxy']['name']
        end

        test 'caps per_page at 100' do
          get :jobs, params: { per_page: 500 }, session: @session
          assert_response :success
          body = JSON.parse(response.body)
          assert_equal 100, body['per_page']
        end

        test 'floors per_page at 1 when zero is requested' do
          # Guards against will_paginate rejecting per_page: 0.
          get :jobs, params: { per_page: 0 }, session: @session
          assert_response :success
          body = JSON.parse(response.body)
          assert_equal 1, body['per_page']
        end

        test 'floors per_page at 1 when a negative value is requested' do
          get :jobs, params: { per_page: -5 }, session: @session
          assert_response :success
          body = JSON.parse(response.body)
          assert_equal 1, body['per_page']
        end

        test 'defaults per_page to 20' do
          get :jobs, session: @session
          assert_response :success
          body = JSON.parse(response.body)
          assert_equal 20, body['per_page']
        end

        test 'per_page=all returns all jobs in one page' do
          5.times { FactoryBot.create(:task_job, smart_proxy: @proxy) }
          get :jobs, params: { per_page: 'all' }, session: @session
          assert_response :success
          body = JSON.parse(response.body)
          assert_equal 5, body['results'].length
          assert_equal 5, body['per_page']
        end

        test 'per_page=all on empty DB does not 500' do
          # Guards against will_paginate rejecting per_page: 0
          get :jobs, params: { per_page: 'all' }, session: @session
          assert_response :success
          body = JSON.parse(response.body)
          assert_equal [], body['results']
          assert_equal 0, body['total']
        end

        test 'returns rows in DESC submitted_at order' do
          # paginated_task_jobs composes TaskJob.recent (ORDER BY submitted_at
          # DESC). If a refactor drops .recent, the field-presence and count
          # assertions above all still pass while the UI's task-history view
          # silently switches to oldest-first.
          oldest = FactoryBot.create(:task_job, smart_proxy: @proxy, submitted_at: 3.hours.ago)
          middle = FactoryBot.create(:task_job, smart_proxy: @proxy, submitted_at: 2.hours.ago)
          newest = FactoryBot.create(:task_job, smart_proxy: @proxy, submitted_at: 1.hour.ago)

          get :jobs, session: @session
          assert_response :success
          body = JSON.parse(response.body)
          assert_equal([newest.job_id, middle.job_id, oldest.job_id],
            body['results'].map { |row| row['job_id'] })
        end
      end

      context 'job_status' do
        test 'returns job status with kind' do
          job = FactoryBot.create(:task_job, :running, smart_proxy: @proxy)

          get :job_status, params: { job_id: job.job_id }, session: @session
          assert_response :success
          body = JSON.parse(response.body)
          assert_equal 'task', body['kind']
          assert_equal 'running', body['status']
          assert_equal job.task_name, body['task_name']
          assert_equal job.targets, body['targets']
          assert_equal @proxy.id, body['smart_proxy']['id']
        end

        test 'returns not_found when job does not exist' do
          get :job_status, params: { job_id: 'nonexistent' }, session: @session
          assert_response :not_found
          assert_match(/Task job nonexistent not found/,
            JSON.parse(response.body)['error']['message'])
        end
      end

      context 'job_result' do
        test 'returns result fields with kind for completed job' do
          ForemanTasks.stubs(:async_task)
          job = FactoryBot.create(:task_job, :success, smart_proxy: @proxy)

          get :job_result, params: { job_id: job.job_id }, session: @session
          assert_response :success
          body = JSON.parse(response.body)
          assert_equal 'task', body['kind']
          assert_equal 'success', body['status']
          assert_equal job.result, body['value']
          assert_equal job.log, body['log']
          assert_equal job.command, body['command']
        end

        test 'returns not_found when job does not exist' do
          get :job_result, params: { job_id: 'nonexistent' }, session: @session
          assert_response :not_found
          assert_match(/Task job nonexistent not found/,
            JSON.parse(response.body)['error']['message'])
        end
      end

      context 'authorization' do
        test 'forbids users without execute_openbolt permission' do
          # Override the admin set by the global set_admin setup (test_helper.rb:176)
          # AND clear apiadmin basic-auth from set_api_user (test_helper.rb:188), so
          # the request runs as our unprivileged user.
          reset_api_credentials
          unprivileged = FactoryBot.create(:user)
          User.current = unprivileged

          get :tasks, params: { smart_proxy_id: @proxy.id },
            session: set_session_user(unprivileged)
          assert_response :forbidden
        end

        test 'forbids unprivileged users from launching tasks' do
          # Specifically pinning launch_task because it has the highest blast
          # radius. A regression dropping :launch_task from the permission list
          # would let any authenticated user trigger arbitrary proxy work.
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
          # Two permissions are needed in real usage: execute_openbolt to call
          # the action, and view_smart_proxies to look up the proxy via
          # SmartProxy.authorized(:view_smart_proxies) in the concern.
          setup_user('execute', 'openbolt', nil, granted)
          setup_user('view', 'smart_proxies', nil, granted)
          User.current = granted

          get :tasks, params: { smart_proxy_id: @proxy.id },
            session: set_session_user(granted)
          assert_response :success
        end

        # The engine.rb permission map is hand-maintained. A typo dropping any
        # action symbol would silently leak access to that endpoint. One forbid
        # check per remaining endpoint pins the map against that regression.
        test 'forbids unprivileged users from listing jobs' do
          reset_api_credentials
          unprivileged = FactoryBot.create(:user)
          User.current = unprivileged

          get :jobs, session: set_session_user(unprivileged)
          assert_response :forbidden
        end

        test 'forbids unprivileged users from reading job status' do
          job = FactoryBot.create(:task_job, smart_proxy: @proxy)
          reset_api_credentials
          unprivileged = FactoryBot.create(:user)
          User.current = unprivileged

          get :job_status, params: { job_id: job.job_id },
            session: set_session_user(unprivileged)
          assert_response :forbidden
        end

        test 'forbids unprivileged users from reading job result' do
          job = FactoryBot.create(:task_job, :success, smart_proxy: @proxy)
          reset_api_credentials
          unprivileged = FactoryBot.create(:user)
          User.current = unprivileged

          get :job_result, params: { job_id: job.job_id },
            session: set_session_user(unprivileged)
          assert_response :forbidden
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

        # The /jobs read endpoints (jobs, job_status, job_result) intentionally
        # do NOT scope by smart-proxy view permissions. A user with only
        # :execute_openbolt sees every recorded job, regardless of which
        # proxy ran it. This is the current product decision (one
        # permission gates all OpenBolt access). If a future security
        # review tightens to require per-proxy view, these three tests
        # fail loudly and we have a place to record the change.
        test 'execute_openbolt without view_smart_proxies still lists jobs' do
          FactoryBot.create(:task_job, smart_proxy: @proxy)
          reset_api_credentials
          granted = FactoryBot.create(:user)
          setup_user('execute', 'openbolt', nil, granted)
          # Deliberately omit view_smart_proxies.
          User.current = granted

          get :jobs, session: set_session_user(granted)
          assert_response :success
          body = JSON.parse(response.body)
          assert_equal 1, body['results'].length
        end

        test 'execute_openbolt without view_smart_proxies still reads job status' do
          job = FactoryBot.create(:task_job, :running, smart_proxy: @proxy)
          reset_api_credentials
          granted = FactoryBot.create(:user)
          setup_user('execute', 'openbolt', nil, granted)
          User.current = granted

          get :job_status, params: { job_id: job.job_id }, session: set_session_user(granted)
          assert_response :success
        end

        test 'execute_openbolt without view_smart_proxies still reads job result' do
          job = FactoryBot.create(:task_job, :success, smart_proxy: @proxy)
          reset_api_credentials
          granted = FactoryBot.create(:user)
          setup_user('execute', 'openbolt', nil, granted)
          User.current = granted

          get :job_result, params: { job_id: job.job_id }, session: set_session_user(granted)
          assert_response :success
        end
      end
    end
  end
end

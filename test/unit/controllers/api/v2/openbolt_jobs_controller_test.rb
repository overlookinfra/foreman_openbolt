# frozen_string_literal: true

require 'test_plugin_helper'

module Api
  module V2
    class OpenboltJobsControllerTest < ActionController::TestCase
      setup do
        @proxy = FactoryBot.create(:smart_proxy)
        @session = set_session_user
        WebMock.reset!
      end

      teardown do
        WebMock.reset!
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

          row = body['results'].first
          %w[job_id name description parameters targets status
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
          get :jobs, params: { per_page: 'all' }, session: @session
          assert_response :success
          body = JSON.parse(response.body)
          assert_equal [], body['results']
          assert_equal 0, body['total']
        end

        test 'returns rows in DESC submitted_at order' do
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
          assert_equal job.task_name, body['name']
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

        # The /jobs read endpoints intentionally do NOT scope by smart-proxy
        # view permissions. A user with only :execute_openbolt sees every
        # recorded job, regardless of which proxy ran it.
        test 'execute_openbolt without view_smart_proxies still lists jobs' do
          FactoryBot.create(:task_job, smart_proxy: @proxy)
          reset_api_credentials
          granted = FactoryBot.create(:user)
          setup_user('execute', 'openbolt', nil, granted)
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

# frozen_string_literal: true

require 'test_plugin_helper'

class CleanupProxyArtifactsTest < ForemanOpenbolt::PluginTestCase
  include Dynflow::Testing

  context 'plan' do
    test 'stores proxy_id and job_id in input' do
      action = create_and_plan_action(Actions::ForemanOpenbolt::CleanupProxyArtifacts, 42, 'job-123')
      assert_equal 42, action.input[:proxy_id]
      assert_equal 'job-123', action.input[:job_id]
    end
  end

  context 'rescue_strategy' do
    test 'uses Skip rescue strategy' do
      action = create_action(Actions::ForemanOpenbolt::CleanupProxyArtifacts)
      assert_equal Dynflow::Action::Rescue::Skip, action.rescue_strategy
    end
  end

  context 'run' do
    test 'calls delete_job_artifacts when proxy exists' do
      proxy = FactoryBot.create(:smart_proxy)
      stub = stub_request(:delete, "#{proxy.url}/openbolt/job/job-456/artifacts")
             .to_return(status: 200, body: '{"deleted": true}', headers: { 'Content-Type' => 'application/json' })

      action = create_and_plan_action(Actions::ForemanOpenbolt::CleanupProxyArtifacts, proxy.id, 'job-456')
      run_action(action)

      assert_requested(stub)
    end

    test 'does not call API when proxy not found' do
      stub = stub_request(:delete, %r{openbolt/job})
      action = create_and_plan_action(Actions::ForemanOpenbolt::CleanupProxyArtifacts, -1, 'job-456')
      run_action(action)
      assert_not_requested(stub)
    end

    test 'does not raise when API call fails' do
      proxy = FactoryBot.create(:smart_proxy)
      stub_request(:delete, "#{proxy.url}/openbolt/job/job-456/artifacts")
        .to_return(status: 500, body: 'Internal Server Error')

      action = create_and_plan_action(Actions::ForemanOpenbolt::CleanupProxyArtifacts, proxy.id, 'job-456')
      assert_nothing_raised { run_action(action) }
    end
  end
end

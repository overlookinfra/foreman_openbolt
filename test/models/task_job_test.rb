# frozen_string_literal: true

require 'test_plugin_helper'

class TaskJobTest < ForemanOpenbolt::PluginTestCase
  context 'status helpers' do
    test 'completed? returns true for completed statuses' do
      ForemanOpenbolt::TaskJob::COMPLETED_STATUSES.each do |status|
        job = FactoryBot.build(:task_job, status: status)
        assert job.completed?, "Expected completed? to be true for status '#{status}'"
      end
    end

    test 'completed? returns false for running statuses' do
      ForemanOpenbolt::TaskJob::RUNNING_STATUSES.each do |status|
        job = FactoryBot.build(:task_job, status: status)
        assert_not job.completed?, "Expected completed? to be false for status '#{status}'"
      end
    end

    test 'running? returns true for running statuses' do
      ForemanOpenbolt::TaskJob::RUNNING_STATUSES.each do |status|
        job = FactoryBot.build(:task_job, status: status)
        assert job.running?, "Expected running? to be true for status '#{status}'"
      end
    end

    test 'running? returns false for completed statuses' do
      ForemanOpenbolt::TaskJob::COMPLETED_STATUSES.each do |status|
        job = FactoryBot.build(:task_job, status: status)
        assert_not job.running?, "Expected running? to be false for status '#{status}'"
      end
    end
  end

  context 'duration' do
    # submitted_at is set automatically by callback, but test nil is handled correctly
    test 'returns nil when submitted_at is nil' do
      job = FactoryBot.build(:task_job, submitted_at: nil)
      assert_nil job.duration
    end

    test 'returns nil when completed_at is nil' do
      job = FactoryBot.build(:task_job, completed_at: nil)
      assert_nil job.duration
    end

    test 'returns difference in seconds when both timestamps present' do
      submitted = Time.current
      completed = submitted + 45.seconds
      job = FactoryBot.build(:task_job, submitted_at: submitted, completed_at: completed)
      assert_in_delta 45.0, job.duration, 0.1
    end
  end

  context 'target_count' do
    test 'returns 0 when targets is nil' do
      job = FactoryBot.build(:task_job)
      job.targets = nil
      assert_equal 0, job.target_count
    end

    test 'returns correct count for populated targets' do
      job = FactoryBot.build(:task_job, targets: ['a.com', 'b.com', 'c.com'])
      assert_equal 3, job.target_count
    end
  end

  context 'formatted_targets' do
    test 'returns empty string when targets is nil' do
      job = FactoryBot.build(:task_job)
      job.targets = nil
      assert_equal '', job.formatted_targets
    end

    test 'returns CSV string for populated targets' do
      job = FactoryBot.build(:task_job, targets: ['host1.com', 'host2.com'])
      assert_equal 'host1.com, host2.com', job.formatted_targets
    end
  end

  context 'validations' do
    test 'valid with all required attributes' do
      job = FactoryBot.build(:task_job)
      assert job.valid?
    end

    test 'invalid without task_name' do
      job = FactoryBot.build(:task_job, task_name: nil)
      assert_not job.valid?
      assert_includes job.errors[:task_name], "can't be blank"
    end

    test 'invalid without job_id' do
      job = FactoryBot.build(:task_job, job_id: nil)
      assert_not job.valid?
      assert_includes job.errors[:job_id], "can't be blank"
    end

    test 'invalid with duplicate job_id' do
      FactoryBot.create(:task_job, job_id: 'unique-id')
      duplicate = FactoryBot.build(:task_job, job_id: 'unique-id')
      assert_not duplicate.valid?
      assert_includes duplicate.errors[:job_id], 'has already been taken'
    end

    test 'invalid with unknown status' do
      job = FactoryBot.build(:task_job, status: 'unknown')
      assert_not job.valid?
      assert_includes job.errors[:status], 'is not included in the list'
    end

    test 'invalid without targets' do
      job = FactoryBot.build(:task_job, targets: nil)
      assert_not job.valid?
      assert_includes job.errors[:targets], "can't be blank"
    end
  end

  context 'scopes' do
    setup do
      @proxy = FactoryBot.create(:smart_proxy)
      @pending_job = FactoryBot.create(:task_job, smart_proxy: @proxy, status: 'pending')
      @running_job = FactoryBot.create(:task_job, smart_proxy: @proxy, status: 'running')
      @success_job = FactoryBot.create(:task_job, :success, smart_proxy: @proxy)
      @failure_job = FactoryBot.create(:task_job, :failure, smart_proxy: @proxy)
    end

    test 'running scope returns pending and running jobs' do
      results = ForemanOpenbolt::TaskJob.running
      assert_includes results, @pending_job
      assert_includes results, @running_job
      assert_not_includes results, @success_job
      assert_not_includes results, @failure_job
    end

    test 'completed scope returns completed jobs' do
      results = ForemanOpenbolt::TaskJob.completed
      assert_includes results, @success_job
      assert_includes results, @failure_job
      assert_not_includes results, @pending_job
      assert_not_includes results, @running_job
    end

    test 'recent scope orders by submitted_at' do
      results = ForemanOpenbolt::TaskJob.recent
      submitted_times = results.map(&:submitted_at)
      assert_equal submitted_times, submitted_times.sort.reverse
    end

    test 'for_proxy scope filters by smart proxy' do
      other_proxy = FactoryBot.create(:smart_proxy)
      other_job = FactoryBot.create(:task_job, smart_proxy: other_proxy)

      results = ForemanOpenbolt::TaskJob.for_proxy(@proxy)
      assert_includes results, @pending_job
      assert_not_includes results, other_job
    end
  end

  context 'callbacks' do
    test 'set_submitted_at sets submitted_at on create when nil' do
      job = FactoryBot.create(:task_job, submitted_at: nil)
      assert_not_nil job.submitted_at
    end

    test 'set_submitted_at does not override existing submitted_at' do
      custom_time = 1.hour.ago
      job = FactoryBot.create(:task_job, submitted_at: custom_time)
      assert_in_delta custom_time.to_f, job.submitted_at.to_f, 1.0
    end

    test 'set_completed_at sets completed_at when status changes to completed' do
      job = FactoryBot.create(:task_job, status: 'running')
      assert_nil job.completed_at

      job.update!(status: 'success')
      assert_not_nil job.completed_at
    end

    test 'set_completed_at does not set completed_at when status stays running' do
      job = FactoryBot.create(:task_job, status: 'running')
      job.update!(task_name: 'different::task')
      assert_nil job.completed_at
    end

    test 'cleanup_proxy_artifacts schedules Dynflow action when result is saved' do
      job = FactoryBot.create(:task_job, status: 'success', completed_at: Time.current)
      ForemanTasks.expects(:async_task).with(
        ::Actions::ForemanOpenbolt::CleanupProxyArtifacts,
        job.smart_proxy_id,
        job.job_id
      )

      job.update!(result: { 'items' => [] })
    end

    test 'cleanup_proxy_artifacts does not schedule cleanup for running jobs' do
      job = FactoryBot.create(:task_job, status: 'running')
      ForemanTasks.expects(:async_task).never

      job.update!(result: { 'items' => [] })
    end

    test 'cleanup_proxy_artifacts does not raise when scheduling fails' do
      job = FactoryBot.create(:task_job, status: 'success', completed_at: Time.current)
      ForemanTasks.expects(:async_task).raises(StandardError, 'Dynflow unavailable')

      assert_nothing_raised do
        job.update!(result: { 'items' => [] })
      end
      assert_equal({ 'items' => [] }, job.reload.result)
    end
  end

  context 'create_from_execution!' do
    test 'creates a task job with the correct attributes' do
      proxy = FactoryBot.create(:smart_proxy)
      job = ForemanOpenbolt::TaskJob.create_from_execution!(
        proxy: proxy,
        task_name: 'mymod::mytask',
        task_description: 'Restart a service',
        targets: ['web1.example.com'],
        job_id: 'exec-123',
        parameters: { 'service' => 'nginx' },
        options: { 'transport' => 'ssh' }
      )

      assert_equal 'exec-123', job.job_id
      assert_equal proxy, job.smart_proxy
      assert_equal 'mymod::mytask', job.task_name
      assert_equal 'Restart a service', job.task_description
      assert_equal ['web1.example.com'], job.targets
      assert_equal({ 'service' => 'nginx' }, job.task_parameters)
      assert_equal({ 'transport' => 'ssh' }, job.openbolt_options)
      assert_equal 'pending', job.status
      assert_not_nil job.submitted_at
    end
  end

  context 'update_from_proxy_result!' do
    setup do
      @job = FactoryBot.create(:task_job, status: 'running')
      ForemanTasks.stubs(:async_task)
    end

    test 'updates status, command, result, and log from proxy result' do
      @job.update_from_proxy_result!({
        'status' => 'success',
        'command' => 'bolt task run mymod::install',
        'value' => { 'items' => [{ 'status' => 'success' }] },
        'log' => 'Task completed successfully',
      })

      @job.reload
      assert_equal 'success', @job.status
      assert_equal 'bolt task run mymod::install', @job.command
      assert_equal({ 'items' => [{ 'status' => 'success' }] }, @job.result)
      assert_equal 'Task completed successfully', @job.log
    end

    test 'skips update for blank proxy result' do
      original_status = @job.status
      @job.update_from_proxy_result!(nil)
      assert_equal original_status, @job.reload.status
    end

    test 'skips update for empty hash' do
      original_status = @job.status
      @job.update_from_proxy_result!({})
      assert_equal original_status, @job.reload.status
    end

    test 'only updates fields present in the result' do
      @job.update_from_proxy_result!({ 'status' => 'failure' })
      @job.reload
      assert_equal 'failure', @job.status
      assert_nil @job.command
      assert_nil @job.result
    end

    test 'sets result to nil when key is present with nil value' do
      @job.update!(result: { 'items' => [{ 'status' => 'success' }] })
      @job.update_from_proxy_result!({ 'status' => 'success', 'value' => nil })
      @job.reload
      assert_nil @job.result
    end
  end
end

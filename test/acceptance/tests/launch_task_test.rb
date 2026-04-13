# frozen_string_literal: true

require_relative '../acceptance_helper'

# Tests launching various task types and verifying their execution results.
class LaunchTaskTest < AcceptanceTestCase
  def setup
    super
    foreman_login
  end

  def test_echo_task_succeeds_on_all_targets
    launch_task_via_ui('acceptance::echo',
      params: { 'message' => 'hello from acceptance test' })

    assert_task_completed
    assert_result_has_content
    assert_result_contains 'hello from acceptance test'
    assert_result_contains 'hostname'
  end

  def test_noop_task_succeeds
    launch_task_via_ui('acceptance::noop_task')
    assert_task_completed
    assert_result_has_content
  end

  def test_complex_params_task_succeeds
    launch_task_via_ui('acceptance::complex_params',
      params: {
        'required_string' => 'test_value',
        'array_param' => '["a","b","c"]',
        'with_default' => 'overridden',
      })

    assert_task_completed
    assert_result_has_content
    assert_result_contains 'test_value'
    assert_result_contains 'overridden'
  end

  def test_slow_task_transitions_through_running
    launch_task_via_ui('acceptance::slow_task', params: { 'seconds' => '8' })
    assert_selector '.pf-v5-c-label', text: /Running/i, wait: 30
    assert_task_completed
    assert_result_has_content
  end

  def test_failing_task_shows_failure_with_error_detail
    launch_task_via_ui('acceptance::failing_task')
    assert_task_failed
    assert_result_contains 'This task always fails'
  end

  def test_run_another_task_navigates_back
    launch_task_via_ui('acceptance::noop_task')
    assert_task_completed
    click_button 'Run Another Task'
    assert_selector 'h1', text: 'Launch OpenBolt Task', wait: 15
  end

  def test_launch_button_disabled_until_all_selections_made
    visit '/foreman_openbolt/page_launch_task'
    assert_selector '#smart-proxy-input', wait: 15

    # No selections at all
    assert find('button', text: /Launch Task/).disabled?,
      'Expected Launch Task disabled with no selections'

    # Proxy only
    select_first_proxy
    assert_selector '#task-name-input option', minimum: 2, wait: 15
    assert find('button', text: /Launch Task/).disabled?,
      'Expected Launch Task disabled with only proxy selected'

    # Proxy + task, no targets
    select 'acceptance::noop_task', from: 'task-name-input'
    assert find('button', text: /Launch Task/).disabled?,
      'Expected Launch Task disabled with no targets'

    # Proxy + task + targets — button enables
    select_hosts_via_search('target1')
    assert_selector 'button:not([disabled])', text: /Launch Task/, wait: 10
  end

  def test_running_task_shows_loading_indicator
    launch_task_via_ui('acceptance::slow_task', params: { 'seconds' => '8' })
    # While the job is still polling, LoadingIndicator renders an EmptyState
    # with role=status and a title of "Task is <status>..." (running or pending).
    assert_selector '[role="status"]',
      text: /Task is (running|pending)/i, wait: 30
    assert_selector '.pf-v5-c-empty-state__body',
      text: /update automatically when the task completes/, wait: 5
    assert_task_completed
  end
end

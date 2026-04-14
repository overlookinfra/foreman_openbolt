# frozen_string_literal: true

require_relative '../acceptance_helper'

# Tests that errors are handled gracefully through the full stack.
class ErrorHandlingTest < AcceptanceTestCase
  def setup
    super
    foreman_login
  end

  def test_launch_button_disabled_with_no_matching_hosts
    visit '/foreman_openbolt/page_launch_task'
    assert_selector '#smart-proxy-input', wait: 15
    select_first_proxy
    select_hosts_via_search('nonexistent.example.com')

    assert_selector '#task-name-input option', minimum: 2, wait: 15
    select 'acceptance::echo', from: 'task-name-input'

    assert_selector 'button[type="submit"][disabled]', text: 'Launch Task'
  end

  def test_failing_task_shows_error_in_result
    launch_task_via_ui('acceptance::failing_task')
    assert_task_failed
    assert_result_contains 'This task always fails'
  end

  def test_mixed_target_results_show_per_host_status
    launch_task_via_ui('acceptance::target_conditional',
      params: { 'succeed_on' => 'target1' })

    assert_task_failed
    assert_result_has_content
    # Result should contain output from both targets
    assert_result_contains 'target1'
    assert_result_contains 'target2'
  end
end

# frozen_string_literal: true

require_relative '../acceptance_helper'

# Tests the task history page: listing, navigation, and new entry creation.
class TaskHistoryTest < AcceptanceTestCase
  def setup
    super
    foreman_login
  end

  def test_history_shows_completed_tasks_and_navigation
    # Launch a task to seed history
    launch_task_via_ui('acceptance::echo', params: { 'message' => 'history test' })
    assert_task_completed

    # Visit history and verify the entry appears
    visit '/foreman_openbolt/page_task_history'
    assert_selector 'h1', text: 'Task History', wait: 15
    assert_no_selector '[aria-label="Loading task history"]', wait: 15
    assert_selector 'table[aria-label="Task history table"] tbody tr', minimum: 1
    # Capture the first row so we can confirm a newer entry lands above it.
    # History paginates (default 20 rows), so counting rows is unreliable
    # once history fills the first page.
    first_row_before = first('table[aria-label="Task history table"] tbody tr').text

    # Navigate to execution details from history
    first('a[aria-label="View Details"]').click
    assert_selector 'h1', text: 'Task Execution', wait: 15

    # Launch another task and verify it appears at the top of history.
    launch_task_via_ui('acceptance::noop_task')
    assert_task_completed

    visit '/foreman_openbolt/page_task_history'
    assert_selector 'table[aria-label="Task history table"] tbody tr', minimum: 1, wait: 15
    first_row_after = first('table[aria-label="Task history table"] tbody tr').text
    assert_not_equal first_row_before, first_row_after,
      'Expected newly launched task to appear as the first history row'
  end

  def test_hosts_popover_lists_targets_from_history_row
    # 'target' matches both target1 and target2, so the popover count
    # will be 2.
    launch_task_via_ui('acceptance::noop_task')
    assert_task_completed

    visit '/foreman_openbolt/page_task_history'
    assert_no_selector '[aria-label="Loading task history"]', wait: 15
    assert_selector 'table[aria-label="Task history table"] tbody tr', minimum: 1, wait: 15

    # The hosts count button has aria-label '<count> target hosts'
    within first('table[aria-label="Task history table"] tbody tr') do
      find('button[aria-label$=" target hosts"]').click
    end

    # Popover content is portaled to document body
    assert_selector 'table[aria-label="Target hosts"]', wait: 10
    within 'table[aria-label="Target hosts"]' do
      assert_selector 'td', text: 'target1'
      assert_selector 'td', text: 'target2'
    end
  end

  def test_task_popover_shows_submitted_parameters_on_history_row
    launch_task_via_ui('acceptance::echo',
      params: { 'message' => 'popover history param' })
    assert_task_completed

    visit '/foreman_openbolt/page_task_history'
    assert_no_selector '[aria-label="Loading task history"]', wait: 15
    assert_selector 'table[aria-label="Task history table"] tbody tr', minimum: 1, wait: 15

    # The task name is rendered as a popover trigger whose aria-label is
    # "View details for task <name>"
    first('button[aria-label="View details for task acceptance::echo"]').click

    assert_selector 'table[aria-label="Task parameters"]', wait: 10
    within 'table[aria-label="Task parameters"]' do
      assert_selector 'td', text: 'message'
      assert_selector 'td', text: 'popover history param'
    end
  end
end

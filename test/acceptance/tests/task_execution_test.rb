# frozen_string_literal: true

require_relative '../acceptance_helper'

# Tests for the Task Execution page: URL validation, tab switching, and
# task metadata display on the Task Details tab.
class TaskExecutionTest < AcceptanceTestCase
  def setup
    super
    foreman_login
  end

  def test_execution_page_without_job_id_redirects_to_launch
    # Visiting the execution URL without a job_id query parameter should
    # client-side redirect back to the Launch page (TaskExecution/index.js
    # useEffect with !jobId calls history.push(LAUNCH_TASK)).
    visit '/foreman_openbolt/page_task_execution'
    assert_selector 'h1', text: 'Launch OpenBolt Task', wait: 15
  end

  def test_task_details_tab_shows_task_name_and_submitted_parameters
    launch_task_via_ui('acceptance::echo',
      params: { 'message' => 'details tab test' })
    assert_task_completed

    # Click the "Task Details" tab (second tab in ExecutionDisplay).
    find('.pf-v5-c-tabs__link', text: 'Task Details').click

    # TaskDetails renders task name in a DescriptionList and the
    # submitted parameters in a table with aria-label="Task parameters".
    assert_selector 'dt', text: 'Task Name', wait: 10
    assert_selector 'dd', text: 'acceptance::echo'

    assert_selector 'table[aria-label="Task parameters"]', wait: 10
    within 'table[aria-label="Task parameters"]' do
      assert_selector 'td', text: 'message'
      assert_selector 'td', text: 'details tab test'
    end
  end
end

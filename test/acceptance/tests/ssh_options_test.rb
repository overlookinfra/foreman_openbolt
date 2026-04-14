# frozen_string_literal: true

require_relative '../acceptance_helper'

# Tests that SSH transport options are correctly passed through to the
# OpenBolt CLI and affect task execution.
class SshOptionsTest < AcceptanceTestCase
  def setup
    super
    foreman_login
    visit '/foreman_openbolt/page_launch_task'
    assert_selector '#smart-proxy-input', wait: 15
    select_first_proxy
  end

  def test_default_user_passed_to_bolt
    select_hosts_via_search('target1')
    assert_selector '#task-name-input option', minimum: 2, wait: 15
    select 'acceptance::echo', from: 'task-name-input'
    fill_in 'param_message', with: 'user test'
    click_button 'Launch Task'
    assert_selector 'h1', text: 'Task Execution', wait: 15

    assert_task_completed
    # The default user (from settings) should appear in the bolt command on the Log Output tab
    assert_log_contains '--user=openbolt'
  end

  def test_user_override_passed_to_bolt
    select_hosts_via_search('target1')
    assert_selector '#task-name-input option', minimum: 2, wait: 15
    select 'acceptance::echo', from: 'task-name-input'
    fill_in 'param_message', with: 'override test'

    set_openbolt_option('user', 'root')
    click_button 'Launch Task'
    assert_selector 'h1', text: 'Task Execution', wait: 15

    # Task may fail because root doesn't have the SSH key, but the
    # command should show the overridden user
    assert_selector '.pf-v5-c-label', text: /Success|Failed/i, wait: 120
    assert_log_contains '--user=root'
  end

  def test_host_key_check_false_passed_to_bolt
    select_hosts_via_search('target1')
    assert_selector '#task-name-input option', minimum: 2, wait: 15
    select 'acceptance::noop_task', from: 'task-name-input'

    # host-key-check is a boolean OpenBolt option and must render as a
    # checkbox (ParameterField's boolean branch), not a text input.
    assert_equal 'checkbox', find_by_id('param_host-key-check')['type']

    set_openbolt_option('host-key-check', false)
    click_button 'Launch Task'
    assert_selector 'h1', text: 'Task Execution', wait: 15

    assert_task_completed
    assert_log_contains '--no-host-key-check'
  end

  def test_verbose_flag_passed_to_bolt
    select_hosts_via_search('target1')
    assert_selector '#task-name-input option', minimum: 2, wait: 15
    select 'acceptance::noop_task', from: 'task-name-input'

    # verbose is boolean and must render as a checkbox.
    assert_equal 'checkbox', find_by_id('param_verbose')['type']

    set_openbolt_option('verbose', true)
    click_button 'Launch Task'
    assert_selector 'h1', text: 'Task Execution', wait: 15

    assert_task_completed
    assert_log_contains '--verbose'
  end
end

# frozen_string_literal: true

require_relative '../acceptance_helper'

# Tests that the proxy correctly loads and exposes tasks, and that
# task metadata (parameters) is displayed in the UI.
class TransportOptionsTest < AcceptanceTestCase
  def setup
    super
    foreman_login
    visit '/foreman_openbolt/page_launch_task'
    assert_selector '#smart-proxy-input', wait: 15
    select_first_proxy
  end

  def test_proxy_selection_populates_task_list
    assert_selector '#task-name-input option', minimum: 2, wait: 15
  end

  def test_all_fixture_tasks_discoverable
    assert_selector '#task-name-input option', minimum: 2, wait: 15
    options = all('#task-name-input option').map(&:text)

    %w[echo complex_params failing_task noop_task slow_task target_conditional].each do |task|
      assert options.any?("acceptance::#{task}"),
        "Expected acceptance::#{task} in task list, got: #{options}"
    end
  end

  def test_echo_task_shows_message_param_as_empty_text_input
    assert_selector '#task-name-input option', minimum: 2, wait: 15
    select 'acceptance::echo', from: 'task-name-input'
    message = find_by_id('param_message', wait: 10)
    assert_equal 'text', message['type']
    assert_equal '', message.value
  end

  def test_complex_params_task_populates_fields_with_correct_defaults
    assert_selector '#task-name-input option', minimum: 2, wait: 15
    select 'acceptance::complex_params', from: 'task-name-input'

    # No-default fields render empty.
    assert_equal '', find_by_id('param_required_string', wait: 10).value
    assert_equal '', find_by_id('param_array_param').value
    # with_default has a 'default_value' default in its task metadata;
    # the launch page must populate it when the task is selected
    # (handleTaskChange in LaunchTask/index.js).
    assert_equal 'default_value', find_by_id('param_with_default').value
  end

  def test_slow_task_shows_seconds_param_with_default_value
    assert_selector '#task-name-input option', minimum: 2, wait: 15
    select 'acceptance::slow_task', from: 'task-name-input'
    # slow_task.json declares "default": 5
    assert_equal '5', find_by_id('param_seconds', wait: 10).value
  end

  def test_target_conditional_shows_succeed_on_param_as_empty_text_input
    assert_selector '#task-name-input option', minimum: 2, wait: 15
    select 'acceptance::target_conditional', from: 'task-name-input'
    succeed_on = find_by_id('param_succeed_on', wait: 10)
    assert_equal 'text', succeed_on['type']
    assert_equal '', succeed_on.value
  end

  def test_switching_tasks_swaps_parameter_fields_and_defaults
    assert_selector '#task-name-input option', minimum: 2, wait: 15

    select 'acceptance::echo', from: 'task-name-input'
    assert_equal '', find_by_id('param_message', wait: 10).value

    select 'acceptance::slow_task', from: 'task-name-input'
    assert_no_selector '#param_message', wait: 5
    # Asserting the seconds default of 5 (not just field presence)
    # proves the new task's metadata loaded rather than stale state.
    assert_equal '5', find_by_id('param_seconds', wait: 10).value
  end

  def test_deselecting_proxy_clears_task_selection_and_parameters
    assert_selector '#task-name-input option', minimum: 2, wait: 15
    select 'acceptance::echo', from: 'task-name-input'
    assert_selector '#param_message', wait: 10

    # Deselect by choosing the placeholder option (value="")
    select 'Select Smart Proxy', from: 'smart-proxy-input'

    # Task selection and its parameters should be cleared, showing the
    # "Select a task to see parameters" empty state.
    assert_no_selector '#param_message', wait: 10
    assert_selector '.pf-v5-c-empty-state',
      text: 'Select a task to see parameters', wait: 10
  end

  def test_transport_option_renders_as_select_with_ssh_winrm_and_choria
    # The transport OpenBolt option has type ["ssh", "winrm", "choria"]
    # and ParameterField renders array-typed values as a <select>.
    field = find_by_id('param_transport', wait: 10)
    assert_equal 'select', field.tag_name
    option_values = all('#param_transport option').map(&:value)
    assert_equal %w[ssh winrm choria], option_values
    assert_equal 'ssh', field.value
  end

  def test_switching_transport_to_winrm_hides_ssh_only_options
    # SSH-only options (private-key, host-key-check) are present on load
    # because the default transport is ssh.
    assert_selector '#param_host-key-check', wait: 10
    assert_selector '#param_private-key', wait: 10

    # Switching transport to winrm should hide options whose metadata
    # tags them as ssh-only (OpenBoltOptionsSection filters by transport).
    select 'winrm', from: 'param_transport'
    assert_no_selector '#param_host-key-check', wait: 10
    assert_no_selector '#param_private-key', wait: 10

    # Switching back restores them
    select 'ssh', from: 'param_transport'
    assert_selector '#param_host-key-check', wait: 10
    assert_selector '#param_private-key', wait: 10
  end

  def test_switching_transport_to_choria_hides_ssh_only_options_and_shows_choria_options
    # SSH-only options are present on load because the default transport is ssh.
    assert_selector '#param_host-key-check', wait: 10
    assert_selector '#param_private-key', wait: 10
    assert_selector '#param_run-as', wait: 10
    assert_selector '#param_sudo-password', wait: 10

    # Switching transport to choria should hide ssh-only options and reveal
    # choria-tagged options (OpenBoltOptionsSection filters by transport).
    select 'choria', from: 'param_transport'
    assert_no_selector '#param_host-key-check', wait: 10
    assert_no_selector '#param_private-key', wait: 10
    assert_no_selector '#param_run-as', wait: 10
    assert_no_selector '#param_sudo-password', wait: 10

    assert_selector '#param_choria-config-file', wait: 10
    assert_selector '#param_choria-ssl-ca', wait: 10
    assert_selector '#param_choria-brokers', wait: 10

    # choria-task-agent must render as a <select> whose options match the
    # proxy's enum exactly. The launch form gets the enum from the proxy's
    # option metadata type array, so a drift in the proxy-side enum (or a
    # mismatch with engine.rb's CHORIA_TASK_AGENTS collection shown on the
    # Settings page) would only surface at task launch time otherwise.
    task_agent = find_by_id('param_choria-task-agent', wait: 10)
    assert_equal 'select', task_agent.tag_name
    assert_equal %w[bolt_tasks shell], all('#param_choria-task-agent option').map(&:value)
    assert_equal 'bolt_tasks', task_agent.value

    # Switching back to ssh restores ssh-only options and hides choria-only ones.
    # Includes the select-type field so a future regression that special-cases
    # selects in the transport filter would be caught here.
    select 'ssh', from: 'param_transport'
    assert_selector '#param_host-key-check', wait: 10
    assert_selector '#param_private-key', wait: 10
    assert_no_selector '#param_choria-config-file', wait: 10
    assert_no_selector '#param_choria-task-agent', wait: 10
    assert_no_selector '#param_choria-brokers', wait: 10
  end
end

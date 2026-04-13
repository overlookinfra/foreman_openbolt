# frozen_string_literal: true

require_relative '../acceptance_helper'

# Tests that Foreman settings correctly populate the OpenBolt options UI
# and that changes to settings are reflected in the plugin's behavior.
# This exercises the settings lookup bug fix (Foreman.settings vs Setting.where).
class SettingsTest < AcceptanceTestCase
  def setup
    super
    foreman_login
  end

  def test_openbolt_user_setting_populates_default
    visit '/foreman_openbolt/page_launch_task'
    assert_selector '#smart-proxy-input', wait: 15
    select_first_proxy

    # The user option should show the value configured during acceptance:up
    assert_selector '#param_user', wait: 10
    assert_equal 'openbolt', find_by_id('param_user').value
  end

  # The string the UI shows in an encrypted-default field so the user can tell
  # a saved value exists without exposing it to the browser. Kept in sync with
  # ENCRYPTED_PLACEHOLDER in task_controller.rb and ENCRYPTED_DEFAULT_PLACEHOLDER
  # in webpack/src/Components/common/constants.js.
  ENCRYPTED_DEFAULT_PLACEHOLDER = '[Use saved encrypted default]'

  def test_encrypted_setting_shows_placeholder_and_is_overrideable
    # Scope the saved password to this test so it does not leak into other
    # task launches (merge_encrypted_defaults would inject it into bolt).
    update_foreman_setting('openbolt_password', 'acceptance-test-password')
    begin
      visit '/foreman_openbolt/page_launch_task'
      assert_selector '#smart-proxy-input', wait: 15
      select_first_proxy

      # With a saved encrypted setting, the field prefills with the placeholder
      # string so the user knows the saved value will be used. The real value
      # is never sent to the browser.
      field = find_by_id('param_password', wait: 10)
      assert_equal 'password', field['type']
      assert_equal ENCRYPTED_DEFAULT_PLACEHOLDER, field.value.to_s

      # Expanding the row reveals a warning that an encrypted default is saved.
      # The FieldTable renders an expand toggle in the first cell of each row;
      # click the first button within the row containing our field.
      within(:xpath, "//tr[.//input[@id='param_password']]") do
        first('button').click
      end
      assert_selector '.pf-v5-c-helper-text__item',
        text: /saved, encrypted default/i, wait: 10

      # Typing a new value must replace the placeholder so the task uses
      # what the user entered instead of the saved default.
      field.fill_in with: 'override-value'
      assert_equal 'override-value', field.value.to_s
    ensure
      update_foreman_setting('openbolt_password', '')
    end
  end

  def test_changing_user_setting_updates_launch_page
    # Change the setting through the Foreman settings UI
    update_foreman_setting('openbolt_user', 'newuser')

    # Verify the launch page reflects the change
    visit '/foreman_openbolt/page_launch_task'
    assert_selector '#smart-proxy-input', wait: 15
    select_first_proxy
    assert_selector '#param_user', wait: 10
    assert_equal 'newuser', find_by_id('param_user').value

    # Restore the original value
    update_foreman_setting('openbolt_user', 'openbolt')
  end

  def test_host_key_check_setting_flows_through_to_checkbox_state
    visit '/foreman_openbolt/page_launch_task'
    assert_selector '#smart-proxy-input', wait: 15
    select_first_proxy

    # openbolt_host-key-check is a boolean Foreman setting; the
    # acceptance fixture (rakelib/acceptance.rake) sets it to false so
    # SSH does not reject the ephemeral target containers. The registered
    # default in engine.rb is true, so if the Foreman setting lookup
    # were broken, the checkbox would render checked. Asserting
    # unchecked here proves the configured value (false) flowed through.
    field = find_by_id('param_host-key-check', wait: 10)
    assert_equal 'checkbox', field['type']
    refute field.checked?,
      'Expected host-key-check to be unchecked, matching the acceptance fixture value'
  end
end

# frozen_string_literal: true

require_relative '../acceptance_helper'

# Tests the parameter table rendering logic: required indicator
# based on the Optional[...] type prefix, and the expandable row
# that reveals type and description for each parameter.
class ParameterTableTest < AcceptanceTestCase
  def setup
    super
    foreman_login
    visit '/foreman_openbolt/page_launch_task'
    assert_selector '#smart-proxy-input', wait: 15
    select_first_proxy
    assert_selector '#task-name-input option', minimum: 2, wait: 15
    select 'acceptance::complex_params', from: 'task-name-input'
    assert_selector '#param_required_string', wait: 10
  end

  def test_required_param_shows_required_indicator
    # ParametersSection flags params whose type does not start with
    # "optional" as required, and FieldTable renders a span with
    # role=img and aria-label="Required" in those rows.
    within(:xpath, "//tr[.//input[@id='param_required_string']]") do
      assert_selector 'span[role="img"][aria-label="Required"]'
    end
  end

  def test_optional_param_has_no_required_indicator
    within(:xpath, "//tr[.//input[@id='param_optional_string']]") do
      assert_no_selector 'span[role="img"][aria-label="Required"]'
    end
  end

  def test_expanding_required_param_row_shows_type_description_and_required_warning
    within(:xpath, "//tr[.//input[@id='param_required_string']]") do
      first('button').click
    end

    # The expanded row is a sibling in the same Tbody. Assertions on
    # the page level since the ExpandableRowContent is outside the
    # trigger row's scope.
    assert_selector '.pf-v5-c-helper-text__item',
      text: 'This field is required', wait: 5
    assert_selector '.pf-v5-c-helper-text__item code', text: 'String'
    assert_selector '.pf-v5-c-helper-text__item',
      text: 'A required string parameter'
  end

  def test_expanding_optional_param_row_shows_type_and_description_without_required_warning
    within(:xpath, "//tr[.//input[@id='param_optional_string']]") do
      first('button').click
    end

    assert_selector '.pf-v5-c-helper-text__item code', text: 'Optional[String]'
    assert_selector '.pf-v5-c-helper-text__item',
      text: 'An optional string parameter'
    assert_no_selector '.pf-v5-c-helper-text__item',
      text: 'This field is required'
  end
end

# frozen_string_literal: true

require_relative '../acceptance_helper'

# Tests for HostSelector-specific affordances: the search query chip
# and the "Clear all target selections" link.
class HostSelectorTest < AcceptanceTestCase
  def setup
    super
    foreman_login
    visit '/foreman_openbolt/page_launch_task'
    assert_selector '#smart-proxy-input', wait: 15
    select_first_proxy
  end

  def test_clear_chips_link_empties_targets_and_removes_chip
    select_hosts_via_search('target1')

    # The Targets label is conditional on targets.length > 0
    # (LaunchTask/index.js:230).
    assert_selector '.pf-v5-c-label', text: /Targets:\s*\d+/, wait: 15

    # Click the "Clear all target selections" button (ouiaId=clear-chips).
    find('[data-ouia-component-id="clear-chips"]').click

    # Targets label disappears and the clear-chips button itself
    # unmounts once there are no selections.
    assert_no_selector '.pf-v5-c-label', text: /Targets:/, wait: 10
    assert_no_selector '[data-ouia-component-id="clear-chips"]', wait: 5
  end
end

# frozen_string_literal: true

require 'capybara'
require 'capybara/dsl'
require 'selenium-webdriver'
require 'test/unit'

# Base class for acceptance tests using Capybara + Selenium Chrome.
# Connects to Foreman through a remote ChromeDriver container and
# exercises the plugin UI as a real user would.
class AcceptanceTestCase < Test::Unit::TestCase
  include Capybara::DSL

  # Chrome runs in a separate container and reaches Foreman via the Docker
  # network service name. The test runner connects to ChromeDriver via the
  # exposed port 4444 on the host.
  FOREMAN_URL = ENV.fetch('FOREMAN_URL', 'https://foreman')
  FOREMAN_USER = ENV.fetch('FOREMAN_USER', 'admin')
  FOREMAN_PASS = ENV.fetch('FOREMAN_PASS', 'changeme')
  CHROMEDRIVER_URL = ENV.fetch('CHROMEDRIVER_URL', 'http://localhost:4444')

  def setup
    Capybara.app_host = FOREMAN_URL
    Capybara.run_server = false
    Capybara.default_max_wait_time = 15

    Capybara.register_driver :remote_chrome do |app|
      options = Selenium::WebDriver::Chrome::Options.new
      options.add_argument('--headless') unless ENV['HEADFUL']
      options.add_argument('--no-sandbox')
      options.add_argument('--disable-dev-shm-usage')
      options.add_argument('--disable-gpu')
      options.add_argument('--window-size=1280,720')
      options.add_argument('--ignore-certificate-errors')

      Capybara::Selenium::Driver.new(
        app,
        browser: :remote,
        url: CHROMEDRIVER_URL,
        options: options
      )
    end

    Capybara.default_driver = :remote_chrome
    Capybara.javascript_driver = :remote_chrome
  end

  def teardown
    visit '/users/logout'
    Capybara.reset_sessions!
  end

  def foreman_login(user: FOREMAN_USER, password: FOREMAN_PASS)
    visit '/users/login'
    fill_in 'login_login', with: user
    fill_in 'login_password', with: password
    click_button 'Log In'
  end

  # --- Launch page helpers ---

  def select_first_proxy
    assert_selector '#smart-proxy-input option', minimum: 2, wait: 15
    proxy_option = find('#smart-proxy-input option:not([value=""])', match: :first)
    select proxy_option.text, from: 'smart-proxy-input'
  end

  def select_hosts_via_search(query)
    find('[aria-label="Select host targeting method"]').click
    find('[data-ouia-component-id="host_methods"]').find('li', text: 'Search query').click
    search_input = find('.foreman-search-field input[type="text"]', wait: 10)
    search_input.fill_in with: query
  end

  def launch_task_via_ui(task_name, targets: 'target', params: {})
    visit '/foreman_openbolt/page_launch_task'
    assert_selector '#smart-proxy-input', wait: 15

    select_first_proxy
    select_hosts_via_search(targets)

    assert_selector '#task-name-input option', minimum: 2, wait: 15
    select task_name, from: 'task-name-input'

    params.each do |name, value|
      assert_selector "#param_#{name}", wait: 10
      fill_in "param_#{name}", with: value
    end

    click_button 'Launch Task'
    assert_selector 'h1', text: 'Task Execution', wait: 15
  end

  def assert_task_completed
    assert_selector '.pf-v5-c-label', text: /Success|Complete/i, wait: 120
  end

  def assert_task_failed
    assert_selector '.pf-v5-c-label', text: /Failed|Failure|Error/i, wait: 120
  end

  def assert_result_contains(text)
    assert_selector '.pf-v5-c-code-block__code', text: text, wait: 15
  end

  def assert_result_has_content
    assert_no_selector '.pf-v5-c-empty-state', text: 'No result data', wait: 15
    assert_selector '.pf-v5-c-code-block__code', wait: 15
  end

  def assert_log_contains(text)
    # Click the "Log Output" tab to see the bolt command and log
    find('.pf-v5-c-tabs__link', text: 'Log Output').click
    assert_selector '.pf-v5-c-code-block__code', text: text, wait: 15
  end

  # OpenBolt options and task parameters both use param_ prefix for field IDs
  def set_openbolt_option(name, value)
    field = find("#param_#{name}", wait: 10)
    if field.tag_name == 'select'
      field.select value
    elsif field['type'] == 'checkbox'
      value ? field.check : field.uncheck
    else
      field.fill_in with: value
    end
  end

  # --- Settings page helpers ---

  # Update a Foreman setting through the /settings UI. Each setting row
  # has an inline edit button with id=<setting_name> that reveals an
  # input with id=setting-input-<setting_name> and a submit button with
  # ouiaId=submit-edit-btn (see Foreman's SettingValueCell /
  # SettingValueEdit components).
  def update_foreman_setting(setting_name, new_value, category: 'openbolt')
    visit '/settings'
    find("a[href='##{category}_settings_tab']", wait: 10).click

    within("##{category}_settings_tab", wait: 10) do
      find("button##{setting_name}", wait: 10).click
      find("#setting-input-#{setting_name}", wait: 10).fill_in with: new_value
      find("[data-ouia-component-id='submit-edit-btn']").click
    end
  end
end

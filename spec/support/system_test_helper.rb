require 'capybara/rspec'
require 'selenium-webdriver'

# Configure Capybara for system tests
Capybara.configure do |config|
  config.default_driver = :selenium_chrome_headless
  config.javascript_driver = :selenium_chrome_headless
  config.default_max_wait_time = 15  # Increased from 10 to handle async operations
  config.server = :puma, { Silent: true }

  # Configure unique ports for parallel testing
  if ENV['TEST_ENV_NUMBER']
    # Use different ports for each parallel worker
    config.server_port = 9887 + ENV['TEST_ENV_NUMBER'].to_i
  end
end

# Configure Chrome options for headless testing
Capybara.register_driver :selenium_chrome_headless do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  # options.add_argument('--headless')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--disable-gpu')
  options.add_argument('--window-size=1400,1400')

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

# Load all system test helpers
Dir[Rails.root.join('spec/support/system/**/*.rb')].each { |f| require f }

module SystemTestHelper
  include BrowserStateHelper
  include DatePickerHelper
  include ReactSelectHelper
  include MapMarkerHelper
end

RSpec.configure do |config|
  config.include SystemTestHelper

  config.before(:each, type: :system) do
    driven_by :selenium_chrome_headless
  end
end

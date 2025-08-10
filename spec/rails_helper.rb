require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'

abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

# Load support files
Dir[Rails.root.join('spec/support/**/*.rb')].each { |f| require f }

RSpec.configure do |config|
  # Enable parallel test execution
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  # Configure parallel testing
  if ENV['PARALLEL_TESTS']
    # Use the number of available processors, or specify a custom number
    config.before(:suite) do
      # Set up parallel test databases if needed
      Rails.application.load_tasks
      Rake::Task['parallel:create'].invoke rescue nil
      Rake::Task['parallel:migrate'].invoke rescue nil
    end
  end

  # Factory Bot configuration
  config.include FactoryBot::Syntax::Methods

  # Database Cleaner configuration for parallel testing
  config.before(:suite) do
    # Use truncation for parallel tests to avoid transaction conflicts
    if ENV['TEST_ENV_NUMBER']
      DatabaseCleaner.strategy = :truncation
      DatabaseCleaner.clean_with(:truncation)
    else
      DatabaseCleaner.strategy = :transaction
      DatabaseCleaner.clean_with(:truncation)
    end
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

  # Disable transactional fixtures for parallel tests
  if ENV['TEST_ENV_NUMBER']
    config.use_transactional_fixtures = false
  end

  # Include SystemTestHelper for system tests
  config.include SystemTestHelper, type: :system

  # System test cleanup hooks to prevent browser state contamination
  config.before(:each, type: :system) do
    begin
      reset_browser_state if respond_to?(:reset_browser_state)
    rescue => e
      # Log the error but don't fail the test
      puts "Warning: Error in before hook reset_browser_state: #{e.message}"
    end
  end

  config.after(:each, type: :system) do
    begin
      reset_browser_state if respond_to?(:reset_browser_state)
      # Force a page refresh to clear any lingering state
      if page.respond_to?(:execute_script)
        page.execute_script(<<~JS)
          // Clear all timeouts and intervals
          for (let i = 1; i < 99999; i++) {
            window.clearTimeout(i);
            window.clearInterval(i);
          }
          // Clear any event listeners on the map
          if (window.mapInstance) {
            window.mapInstance.off();
          }
        JS
      end
    rescue => e
      # Log the error but don't fail the test
      puts "Warning: Error in after hook reset_browser_state: #{e.message}"
    end
  end
end

# Shoulda Matchers configuration
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

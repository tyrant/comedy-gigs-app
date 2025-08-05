require 'capybara/rspec'
require 'selenium-webdriver'

# Configure Capybara for system tests
Capybara.configure do |config|
  config.default_driver = :selenium_chrome_headless
  config.javascript_driver = :selenium_chrome_headless
  config.default_max_wait_time = 10
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
  options.add_argument('--headless')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--disable-gpu')
  options.add_argument('--window-size=1400,1400')

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

module SystemTestHelper
  # Helper method to set date using HTML5 date picker interaction
  def set_date_via_picker(field_id, target_date)
    find("##{field_id}").click
    sleep 1

    # Set the date value and trigger React's onChange handler properly
    result = page.execute_script(<<~JS)
      const input = document.getElementById('#{field_id}');
      const dateValue = '#{target_date.strftime('%Y-%m-%d')}';

      input.value = dateValue;

      // Create a proper React synthetic event by triggering the onChange handler directly
      const event = {
        target: input,
        currentTarget: input,
        type: 'change',
        bubbles: true,
        cancelable: true,
        preventDefault: function() {},
        stopPropagation: function() {}
      };

      // Find React's onChange handler and call it directly
      const reactProps = Object.keys(input).find(key => key.startsWith('__reactProps'));
      let handlerFound = false;

      if (reactProps && input[reactProps] && input[reactProps].onChange) {
        console.log('Found React props onChange handler');
        input[reactProps].onChange(event);
        handlerFound = true;
      } else {
        // Fallback: try to find React fiber and call onChange
        const reactFiber = Object.keys(input).find(key => key.startsWith('__reactInternalInstance') || key.startsWith('__reactFiber'));
        if (reactFiber && input[reactFiber] && input[reactFiber].memoizedProps && input[reactFiber].memoizedProps.onChange) {
          console.log('Found React fiber onChange handler');
          input[reactFiber].memoizedProps.onChange(event);
          handlerFound = true;
        } else {
          console.log('No React handlers found, using native events');
          // Last resort: dispatch native events and hope React picks them up
          input.dispatchEvent(new Event('input', { bubbles: true }));
          input.dispatchEvent(new Event('change', { bubbles: true }));
        }
      }

      input.blur();

      return {
        value: input.value,
        handlerFound: handlerFound,
        url: window.location.href
      };
    JS

    # Small delay to allow React state updates and debounced handlers
    sleep 1
  end

  # Helper method to select acts using React Select component
  def select_act_via_dropdown(act_name)
    # Click the React Select dropdown to open it
    find('.react-select__control').click
    sleep 1

    # Find and click the option with the act name
    find('.react-select__option', text: act_name).click
    sleep 1

    sleep 2 # Additional wait for debounced API calls
  end
end

RSpec.configure do |config|
  config.include SystemTestHelper

  config.before(:each, type: :system) do
    driven_by :selenium_chrome_headless
  end
end

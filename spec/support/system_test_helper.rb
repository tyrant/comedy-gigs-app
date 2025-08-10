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
  options.add_argument('--headless')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--disable-gpu')
  options.add_argument('--window-size=1400,1400')

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

module SystemTestHelper
  # Clean browser state between tests to prevent contamination
  def reset_browser_state
    # Clear any open popups and React Select state
    page.execute_script(<<~JS)
      // Only close popups if they exist and are open
      if (window.mapInstance && window.mapInstance._popup) {
        window.mapInstance.closePopup();
      }

      // Force close any React Select dropdowns
      const openDropdowns = document.querySelectorAll('.react-select__menu');
      openDropdowns.forEach(dropdown => {
        if (dropdown.parentNode) {
          dropdown.parentNode.removeChild(dropdown);
        }
      });

      // Clear React Select focus state
      const selectControls = document.querySelectorAll('.react-select__control');
      selectControls.forEach(control => {
        control.blur();
        control.classList.remove('react-select__control--is-focused');
        control.classList.remove('react-select__control--menu-is-open');
      });

      // Click outside to ensure any dropdowns are closed
      document.body.click();

      // Clear any stale event listeners or timers
      if (window.clearAllTimeouts) {
        window.clearAllTimeouts();
      }
    JS

    # Small delay to ensure cleanup completes
    sleep 0.5
  end

  # Helper method to set date using HTML5 date picker interaction
  def set_date_via_picker(field_id, target_date)
    find("##{field_id}").click
    sleep 0.5  # Reduced initial sleep

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

    # Wait for debounced API call to complete and markers to stabilize
    wait_for_api_completion
  end

  # Helper method to select acts using React Select component
  def select_act_via_dropdown(act_name)
    # Simple, reliable approach - click dropdown and select option
    find('.react-select__control').click
    sleep 0.5

    # Find and click the option with the act name
    find('.react-select__option', text: act_name).click
    sleep 1

    # Wait for API call triggered by act selection
    wait_for_api_completion
  end

  # Wait for API operations to complete by checking for stable marker state
  def wait_for_api_completion
    # Wait for any existing markers to be present (or none if filtered out)
    # This handles both cases: markers appearing and markers being removed
    sleep 1  # Allow for debounced API calls to start

    # Wait for markers to stabilize (no changes for 1 second)
    marker_count = nil
    stable_count = 0

    10.times do  # Max 10 seconds wait
      current_count = all('.leaflet-marker-icon').count

      if marker_count == current_count
        stable_count += 1
        break if stable_count >= 2  # Stable for 2 checks (1 second)
      else
        stable_count = 0
        marker_count = current_count
      end

      sleep 0.5
    end

    # Additional small delay for final DOM updates
    sleep 0.5
  end

  # Wait for map to be ready and initial markers loaded
  def wait_for_map_ready
    # Clean any previous browser state first
    reset_browser_state

    expect(page).to have_selector('.leaflet-container', wait: 15)
    # Wait for initial API call to complete
    sleep 2  # Allow for initial data loading
    wait_for_api_completion
  end

  # Helper to wait for specific marker count with timeout
  def wait_for_marker_count(expected_count, timeout: 15)
    start_time = Time.current

    loop do
      current_count = all('.leaflet-marker-icon').count
      return true if current_count == expected_count

      if Time.current - start_time > timeout
        raise "Expected #{expected_count} markers, but found #{current_count} after #{timeout}s"
      end

      sleep 0.5
    end
  end

  # Helper to trigger map bounds change and wait for completion
  def set_map_bounds_and_wait(lat, lng, zoom)
    page.execute_script(<<~JS)
      if (window.mapInstance) {
        window.mapInstance.setView([#{lat}, #{lng}], #{zoom});
        window.mapInstance.fire('moveend');
      }
    JS

    # Wait for bounds change API call to complete
    wait_for_api_completion
  end

  # Helper to click venue marker and wait for popup to appear
  def click_venue_marker_and_wait_for_popup(venue_name, timeout: 15)
    # Ensure map is ready and markers are loaded
    wait_for_map_ready
    wait_for_api_completion

    # Retry logic for popup opening
    3.times do |attempt|
      begin
        # For edge cases, add a small delay on retry attempts
        if attempt > 0
          puts "Popup retry attempt #{attempt + 1}, adding delay..."
          sleep 1
        end

        # Close any existing popup cleanly
        if page.has_selector?('.leaflet-popup', wait: 1)
          page.execute_script("if (window.mapInstance && window.mapInstance._popup) { window.mapInstance.closePopup(); }")
          expect(page).not_to have_selector('.leaflet-popup', wait: 3)
        end

        # Find and click the marker
        marker = find(".leaflet-marker-icon[title=\"#{venue_name}\"]", wait: timeout)

        # Try both regular click and JavaScript click
        begin
          marker.click
        rescue
          page.execute_script("arguments[0].click();", marker)
        end

        # Wait for popup to appear
        expect(page).to have_selector('.leaflet-popup', wait: timeout)
        expect(page).to have_selector('.leaflet-popup .venue-popup', wait: 5)

        sleep 0.5
        return # Success, exit retry loop
      rescue Capybara::ElementNotFound => e
        if attempt == 2 # Last attempt
          raise e
        else
          puts "Popup click attempt #{attempt + 1} failed, retrying..."
          sleep 1
        end
      end
    end
  end

  # Helper to wait for popup to appear (for URL-triggered popups)
  def wait_for_popup_to_appear(timeout: 15)
    # Wait for map to be ready first
    wait_for_map_ready
    wait_for_api_completion

    # Retry logic for URL-triggered popups
    3.times do |attempt|
      begin
        # For URL-triggered popups, we need to wait for the URL parsing and venue loading
        sleep 2

        # Wait for popup to appear (URL-triggered popups should appear automatically)
        expect(page).to have_selector('.leaflet-popup', wait: timeout)
        expect(page).to have_selector('.leaflet-popup .venue-popup', wait: 5)

        # Wait for any async content loading within popup
        sleep 1
        return # Success, exit retry loop
      rescue Capybara::ElementNotFound => e
        if attempt == 2 # Last attempt
          raise e
        else
          puts "URL popup attempt #{attempt + 1} failed, retrying..."
          # Refresh the page to retry URL parsing
          page.driver.browser.navigate.refresh if page.driver.respond_to?(:browser)
          wait_for_map_ready
          wait_for_api_completion
        end
      end
    end
  end

  # Helper to close popup and wait for it to disappear
  def close_popup_and_wait
    # Click the popup close button or click outside
    if page.has_selector?('.leaflet-popup-close-button', wait: 1)
      find('.leaflet-popup-close-button').click
    else
      # Click outside the popup to close it
      find('body').click
    end

    # Wait for popup to disappear
    expect(page).not_to have_selector('.leaflet-popup', wait: 10)
    sleep 0.5
  end
end

RSpec.configure do |config|
  config.include SystemTestHelper

  config.before(:each, type: :system) do
    driven_by :selenium_chrome_headless
  end
end

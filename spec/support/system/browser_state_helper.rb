module SystemTestHelper
  module BrowserStateHelper
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

      # Wait for cleanup to complete
      sleep 0.1
    end

    # Helper to close popup and wait for it to disappear
    def close_popup_and_wait
      # Close popup if it exists
      if page.has_selector?('.leaflet-popup', wait: false)
        page.execute_script(<<~JS)
          if (window.mapInstance) {
            window.mapInstance.closePopup();
          }
        JS

        # Wait for popup to disappear
        expect(page).not_to have_selector('.leaflet-popup', wait: 5)
      end
    end
  end
end

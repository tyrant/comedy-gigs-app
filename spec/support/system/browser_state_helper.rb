module SystemTestHelper
  module BrowserStateHelper
    # Clean browser state between tests to prevent contamination
    def reset_browser_state
      # Clear any React Select state
      page.execute_script(<<~JS)
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
  end
end

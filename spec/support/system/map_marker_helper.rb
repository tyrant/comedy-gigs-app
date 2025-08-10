module SystemTestHelper
  module MapMarkerHelper
    # Wait for API operations to complete by checking for stable marker state
    def wait_for_api_completion
      # Wait for markers to stabilize using Capybara's built-in waiting
      # This will wait up to Capybara.default_max_wait_time (15 seconds) for the page to stabilize
      all('.leaflet-marker-icon', wait: 5)
      
      # Small additional wait for DOM updates to complete
      sleep 0.1
    end

    # Wait for map to be ready and initial markers loaded
    def wait_for_map_ready
      # Clean any previous browser state first
      reset_browser_state

      # Wait for map container and initial markers using Capybara's built-in waiting
      expect(page).to have_selector('.leaflet-container', wait: 10)
      wait_for_api_completion
    end

    # Helper to wait for specific marker count with timeout
    def wait_for_marker_count(expected_count, timeout: 10)
      # Use Capybara's built-in waiting instead of manual polling
      expect(page).to have_selector('.leaflet-marker-icon', count: expected_count, wait: timeout)
    end

    # Helper to trigger map bounds change and wait for completion
    def set_map_bounds_and_wait(lat, lng, zoom)
      page.execute_script(<<~JS)
        if (window.mapInstance) {
          window.mapInstance.setView([#{lat}, #{lng}], #{zoom});
          
          // Trigger a custom event to notify our React code
          const event = new CustomEvent('boundsChanged', { 
            detail: { lat: #{lat}, lng: #{lng}, zoom: #{zoom} }
          });
          window.dispatchEvent(event);
        }
      JS
      
      # Wait for API call completion after bounds change
      wait_for_api_completion
    end

    # Helper to click venue marker and wait for popup to appear
    def click_venue_marker_and_wait_for_popup(venue_name, timeout: 10)
      # Find marker by venue name (using title attribute)
      marker = find(".leaflet-marker-icon[title=\"#{venue_name}\"]", wait: timeout)
      
      # Click the marker
      marker.click
      
      # Wait for popup to appear
      expect(page).to have_selector('.leaflet-popup', wait: timeout)
      
      # Wait for popup content to load
      expect(page).to have_selector('.venue-popup', wait: timeout)
    end

    # Helper to wait for popup to appear (for URL-triggered popups)
    def wait_for_popup_to_appear(timeout: 10)
      # Wait for popup to appear
      expect(page).to have_selector('.leaflet-popup', wait: timeout)
      
      # Wait for popup content to load
      expect(page).to have_selector('.venue-popup', wait: timeout)
    end
  end
end

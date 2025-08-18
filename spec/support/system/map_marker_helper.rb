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
      marker = find(".leaflet-marker-icon[title*=\"#{venue_name}\"]", wait: timeout)

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

    # Helper to close popup and wait for it to disappear
    def close_popup_and_wait(timeout: 10)
      find('.leaflet-popup-close-button', wait: timeout).click
      expect(page).not_to have_selector('.leaflet-popup', wait: timeout)
    end

    # Helper to verify gig count is displayed on a venue marker
    def verify_marker_gig_count(venue_name, expected_count, timeout: 10)
      # Find the marker by venue name
      marker = find(".leaflet-marker-icon[title*=\"#{venue_name}\"]", wait: timeout)

      # The gig count should be visible as text overlaid on the marker image
      # We can verify this by checking the title attribute which includes gig count
      title_text = marker['title']

      expected_gig_text = if expected_count == 1
        "(1 gig)"
      else
        "(#{expected_count} gigs)"
      end
      expect(title_text).to include expected_gig_text

      # Additionally, we can verify the marker has a custom icon by checking the src attribute
      # This avoids complex JavaScript execution that may have compatibility issues
      marker_src = marker['src']

      # Verify the marker has a custom icon (data URL) rather than the default icon
      expect(marker_src).to start_with('data:image/png;base64')
    end

    # Helper to verify multiple markers have correct gig counts
    def verify_all_marker_gig_counts(venue_gig_counts, timeout: 10)
      venue_gig_counts.each do |venue_name, expected_count|
        verify_marker_gig_count(venue_name, expected_count, timeout: timeout)
      end
    end

    # Helper to get the actual gig count from a marker's title
    def get_marker_gig_count(venue_name, timeout: 10)
      marker = find(".leaflet-marker-icon[title*=\"#{venue_name}\"]", wait: timeout)
      title_text = marker['title']

      # Extract number from title like "Venue Name (3 gigs)" or "Venue Name (1 gig)"
      if match = title_text.match(/\((\d+) gigs?\)/)
        match[1].to_i
      else
        0
      end
    end
  end
end

module SystemTestHelper
  module MapMarkerHelper
    # Venue markers are HTML buttons titled "Name (N gigs)"; clusters are separate .cluster-marker buttons.
    MAP = ".maplibregl-map".freeze
    VENUE_MARKER = ".venue-marker".freeze

    # Wait until the venues have loaded and the markers show them. The page
    # shows it's loading from the render that changes a filter, and the map
    # is aria-busy until its markers catch up.
    def wait_for_api_completion
      expect(page).to have_no_selector('[role="status"][aria-label="Loading gigs"]')
      expect(page).to have_selector("#{MAP}[aria-busy='false']")
    end

    # Wait for the map to be ready and the initial markers loaded
    def wait_for_map_ready
      reset_browser_state
      expect(page).to have_selector(MAP, wait: 10)
      wait_for_api_completion
    end

    def wait_for_marker_count(expected_count, timeout: 10)
      expect(page).to have_selector(VENUE_MARKER, count: expected_count, wait: timeout)
    end

    # Jump the map to a view; MapLibre zoom 0 shows the world 512px wide
    def set_map_bounds_and_wait(lat, lng, zoom)
      page.execute_script("window.mapInstance.jumpTo({ center: [#{lng}, #{lat}], zoom: #{zoom} })")
      wait_for_api_completion
    end

    def click_venue_marker_and_wait_for_details(venue_name, timeout: 10)
      find("#{VENUE_MARKER}[title*=\"#{venue_name}\"]", wait: timeout).click
      wait_for_venue_details(timeout:)
    end

    # For venue details opened by the URL, or by clicking a marker
    def wait_for_venue_details(timeout: 10)
      expect(page).to have_selector('#venue-details .venue-gigs', wait: timeout)
    end

    def close_venue_and_wait(timeout: 10)
      find('[data-action="close-venue"]', wait: timeout).click
      expect(page).not_to have_selector('#venue-details', wait: timeout)
    end

    # The marker's title carries the count for people and specs; its text is the count itself
    def verify_marker_gig_count(venue_name, expected_count, timeout: 10)
      expected_gig_text = expected_count == 1 ? "(1 gig)" : "(#{expected_count} gigs)"
      marker = find("#{VENUE_MARKER}[title=\"#{venue_name} #{expected_gig_text}\"]", wait: timeout)
      expect(marker).to have_text(expected_count.to_s, exact: true)
    end

    def verify_all_marker_gig_counts(venue_gig_counts, timeout: 10)
      venue_gig_counts.each do |venue_name, expected_count|
        verify_marker_gig_count(venue_name, expected_count, timeout: timeout)
      end
    end

    def get_marker_gig_count(venue_name, timeout: 10)
      marker = find("#{VENUE_MARKER}[title*=\"#{venue_name}\"]", wait: timeout)
      marker['title'][/\((\d+) gigs?\)/, 1].to_i
    end
  end
end

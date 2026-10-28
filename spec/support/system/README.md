# System Test Helpers

This directory contains modularized helper modules for system tests, organized by functionality:

## Modules

1. **browser_state_helper.rb** - Functions for resetting browser state between tests
   - `reset_browser_state` - Clears React Select state

2. **date_picker_helper.rb** - Functions for interacting with HTML5 date pickers
   - `set_date_via_picker` - Sets date values and properly triggers React onChange handlers

3. **react_select_helper.rb** - Functions for interacting with React Select components
   - `select_act_via_dropdown` - Selects acts from the dropdown filter

4. **map_marker_helper.rb** - Functions for interacting with the MapLibre map and markers.
   Venue markers are `.venue-marker` buttons titled "Name (N gigs)"; the map is
   `aria-busy` until its markers match the latest venue data.
   - `wait_for_api_completion` - Waits for the venues to load and the markers to catch up
   - `wait_for_map_ready` - Waits for initial map and markers to load
   - `wait_for_marker_count` - Waits for a specific number of markers to appear
   - `set_map_bounds_and_wait` - Changes map view and waits for API completion
   - `click_venue_marker_and_wait_for_details` - Clicks a venue marker and waits for its details in the panel
   - `wait_for_venue_details` - Waits for the selected venue’s details in the panel
   - `close_venue_and_wait` - Goes back from the venue to the list
   - `verify_marker_gig_count` - Checks a marker's title and the count it shows

## Usage

All modules are included in the main `SystemTestHelper` module in `spec/support/system_test_helper.rb`, 
so all functions are available in system tests automatically.

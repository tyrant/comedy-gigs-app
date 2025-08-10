# System Test Helpers

This directory contains modularized helper modules for system tests, organized by functionality:

## Modules

1. **browser_state_helper.rb** - Functions for resetting browser state between tests
   - `reset_browser_state` - Clears popups, React Select state, and event listeners
   - `close_popup_and_wait` - Closes venue popups and waits for them to disappear

2. **date_picker_helper.rb** - Functions for interacting with HTML5 date pickers
   - `set_date_via_picker` - Sets date values and properly triggers React onChange handlers

3. **react_select_helper.rb** - Functions for interacting with React Select components
   - `select_act_via_dropdown` - Selects acts from the dropdown filter

4. **map_marker_helper.rb** - Functions for interacting with the Leaflet map and markers
   - `wait_for_api_completion` - Waits for markers to stabilize after API calls
   - `wait_for_map_ready` - Waits for initial map and markers to load
   - `wait_for_marker_count` - Waits for a specific number of markers to appear
   - `set_map_bounds_and_wait` - Changes map view and waits for API completion
   - `click_venue_marker_and_wait_for_popup` - Clicks venue markers and waits for popups
   - `wait_for_popup_to_appear` - Waits for URL-triggered popups to appear

## Usage

All modules are included in the main `SystemTestHelper` module in `spec/support/system_test_helper.rb`, 
so all functions are available in system tests automatically.

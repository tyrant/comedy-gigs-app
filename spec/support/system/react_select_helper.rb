module SystemTestHelper
  module ReactSelectHelper
    # Picks an act in the act filter. Typing the name has the server search
    # for it, so the option is there whether or not it's among the suggestions.
    #
    # Under load, headless Chrome sometimes loses window focus mid-test; the
    # select clears what was typed when it's blurred, so the name is typed
    # again until its option shows. React can also swap an option's element
    # for a fresh one between finding it and clicking it (as results arrive),
    # so a stale one is looked up again.
    def select_act_via_dropdown(act_name)
      option = '.react-select__option span'

      3.times do
        find('#act_search').set(act_name)
        break if page.has_css?(option, exact_text: act_name, wait: 5)
      end

      attempts = 0
      begin
        find(option, exact_text: act_name).click
      rescue Selenium::WebDriver::Error::StaleElementReferenceError
        retry if (attempts += 1) < 3
        raise
      end

      wait_for_api_completion
    end
  end
end

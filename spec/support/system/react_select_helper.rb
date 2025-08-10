module SystemTestHelper
  module ReactSelectHelper
    # Helper method to select acts using React Select component
    def select_act_via_dropdown(act_name)
      # Simple, reliable approach - click dropdown and select option
      find('.react-select__control').click

      # Find and click the option with the act name
      find('.react-select__option', text: act_name).click

      # Wait for API call triggered by act selection
      wait_for_api_completion
    end
  end
end

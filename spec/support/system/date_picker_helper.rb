module SystemTestHelper
  module DatePickerHelper
    # Helper method to set date using HTML5 date picker interaction
    def set_date_via_picker(field_id, target_date)
      find("##{field_id}").click

      # Set the date value and trigger React's onChange handler properly
      page.execute_script(<<~JS)
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
  end
end

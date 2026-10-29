require 'rails_helper'

RSpec.describe 'The theme button', type: :system, js: true do
  def theme = page.evaluate_script('document.documentElement.dataset.theme')

  # The map's basemap swaps in the background, so wait for it
  def expect_map_background(colour)
    page.document.synchronize(10) do
      background = page.evaluate_script("(() => { try { return window.mapInstance.getStyle().layers[0].paint['background-color']; } catch { return null; } })()")
      raise Capybara::ExpectationNotMet, "map background is #{background.inspect}" unless background == colour
    end
  end

  it 'switches to dark and back, map and all, and remembers the choice' do
    visit root_path
    wait_for_map_ready
    expect(theme).to eq 'light' # the test browser's system setting

    click_button 'Switch to dark mode'
    expect(page).to have_button('Switch to light mode')
    expect(theme).to eq 'dark'
    expect(page.evaluate_script("getComputedStyle(document.body).backgroundColor")).to eq 'rgb(17, 17, 20)'
    expect_map_background('#1b1b20')

    visit root_path
    expect(page).to have_button('Switch to light mode')
    expect(theme).to eq 'dark'

    click_button 'Switch to light mode'
    expect(theme).to eq 'light'
    expect_map_background('#f4f4f2')
  end
end

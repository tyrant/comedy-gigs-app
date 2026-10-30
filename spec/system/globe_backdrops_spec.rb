require 'rails_helper'

RSpec.describe 'Backdrops round the globe', type: :system, js: true do
  BACKDROPS = %w[/images/backdrops/one.jpg /images/backdrops/two.jpg].freeze

  around do |example|
    original = Rails.configuration.x.globe_backdrops
    Rails.configuration.x.globe_backdrops = BACKDROPS
    example.run
  ensure
    Rails.configuration.x.globe_backdrops = original
  end

  def backdrop = page.evaluate_script("document.querySelector('[aria-label=\"Map of venues\"]').dataset.backdrop || null")

  def zoom_to(zoom) = page.execute_script("window.mapInstance.jumpTo({ zoom: #{zoom} })")

  it 'shows one zoomed right out, and another each time the globe has filled the map' do
    visit "#{root_path}?lat=20&lng=0&zoom=0.5"
    wait_for_map_ready

    first = backdrop
    expect(BACKDROPS).to include first

    zoom_to(1) # still space round it: no change
    expect(backdrop).to eq first

    zoom_to(6) # the globe fills the map
    expect(backdrop).to eq first
    zoom_to(0.5)
    expect(backdrop).to eq(BACKDROPS.find { |path| path != first })
  end

  it 'shows none while the globe fills the map' do
    visit "#{root_path}?lat=20&lng=0&zoom=6"
    wait_for_map_ready

    expect(backdrop).to be_nil
  end
end

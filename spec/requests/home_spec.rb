require 'rails_helper'

RSpec.describe 'GET /' do
  before { get '/' }

  let(:page) { Nokogiri::HTML(response.body) }

  def meta(property) = page.at_css("meta[property='#{property}'], meta[name='#{property}']")&.[]('content')

  it 'names the site and describes it' do
    expect(page.at_css('html')['lang']).to eq 'en'
    expect(page.at_css('title').text).to start_with 'Gigs'
    expect(meta('description')).to be_present
  end

  it 'gives link previews a title, description and absolute image URL' do
    expect(meta('og:title')).to eq 'Gigs'
    expect(meta('og:description')).to be_present
    expect(meta('og:image')).to eq 'http://www.example.com/og-image.png'
    expect(meta('twitter:card')).to eq 'summary_large_image'
  end

  it 'links icons that exist' do
    hrefs = page.css('link[rel=icon], link[rel=apple-touch-icon]').map { |link| link['href'] }
    expect(hrefs).to contain_exactly('/favicon.ico', '/icon.svg', '/apple-touch-icon.png')
    hrefs.each { |href| expect(Rails.public_path.join(href.delete_prefix('/'))).to exist }
    expect(Rails.public_path.join('og-image.png')).to exist
  end

  it 'hands the map both basemaps and its worker' do
    root = page.at_css('#root')
    expect(root['data-map-style-light']).to be_present
    expect(root['data-map-style-dark']).to be_present
    expect(root['data-map-worker']).to match %r{\A/assets/maplibre-gl-worker-\h+\.js\z}
  end
end

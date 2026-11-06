require 'rails_helper'

RSpec.describe ImageCheck do
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:check) { described_class.new(adapter: [ :test, stubs ]) }

  let(:live) { 'https://s1.ticketm.net/dam/v/venue.jpg' }
  let(:dead) { 'https://website.tmaster.org/statics/salle/s_483_4.jpg' }

  around do |example|
    Rails.configuration.x.check_images = true
    example.run
  ensure
    Rails.configuration.x.check_images = false
  end

  let(:asked) { Hash.new(0) }

  before do
    stubs.head(live) { asked[live] += 1; [ 200, { 'Content-Type' => 'image/jpeg' }, '' ] }
    stubs.head(dead) { asked[dead] += 1; [ 404, { 'Content-Type' => 'application/xml' }, '' ] }
  end

  it 'keeps the sizes whose image loads' do
    expect(check.loading({ 'large' => live, 'thumb' => dead })).to eq('large' => live)
  end

  it 'drops an image whose host is unreachable' do
    stubs.head('https://static.ticketmaster.fr/s_942_4.jpg') { raise Faraday::ConnectionFailed, 'Could not resolve host' }

    expect(check.loading({ 'large' => 'https://static.ticketmaster.fr/s_942_4.jpg' })).to eq({})
  end

  it "takes the record's own images on trust, without asking" do
    expect(check.loading({ 'large' => dead }, known: { 'medium' => dead })).to eq('large' => dead)
    expect(asked[dead]).to eq 0
  end

  it 'asks about each image once a run' do
    3.times { check.loading({ 'large' => dead, 'medium' => dead, 'thumb' => live }) }

    expect(asked).to eq(dead => 1, live => 1)
  end

  it 'checks nothing when turned off' do
    Rails.configuration.x.check_images = false

    expect(check.loading({ 'large' => dead })).to eq('large' => dead)
  end
end

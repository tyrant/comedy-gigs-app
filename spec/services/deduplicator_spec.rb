require 'rails_helper'

RSpec.describe Deduplicator do
  let(:wellington) { { city: 'Wellington', latitude: -41.2905, longitude: 174.7768 } }

  let!(:opera_house) { create :venue, name: 'The Opera House Wellington', **wellington, sources: { 'ticketmaster' => 'KovZ1' } }
  let!(:opera_house_again) { create :venue, name: 'The Opera House', **wellington, latitude: -41.2903, sources: { 'eventfinda' => '501' } }
  let!(:sydney_opera_house) { create :venue, name: 'Opera House', city: 'Sydney', latitude: -33.8568, longitude: 151.2153 }

  let!(:hans) { create :act, name: 'Hans Kim', sources: { 'ticketmaster' => 'A1' } }
  let!(:hans_again) { create :act, name: 'Hans Kim', sources: { 'ticketmaster' => 'A2' } }

  let(:start) { 2.weeks.from_now.change(hour: 7) }
  let!(:show) { create :gig, name: 'Nikki Glaser: The Vegas Residency', venue: opera_house, start_time: start, end_time: nil, acts: [ hans ] }
  let!(:package) { create :gig, name: 'Nikki Glaser | Official Caesars Ticket + Hotel Packages', venue: opera_house_again, start_time: start, end_time: nil, acts: [ hans_again ] }
  let!(:late_show) { create :gig, name: 'Nikki Glaser: The Vegas Residency', venue: opera_house, start_time: start + 2.hours, end_time: nil }

  it 'lists what it would merge without changing anything' do
    results = described_class.call(dry_run: true)

    expect(results.transform_values(&:size)).to eq(venues: 1, acts: 1, gigs: 0) # the gigs only meet once their venues merge
    expect(results[:venues].first).to start_with 'The Opera House Wellington'
    expect([ Venue.count, Act.count, Gig.count ]).to eq [ 3, 2, 3 ]
  end

  it 'merges venues, then acts, then the gigs that brings together' do
    results = described_class.call

    expect(results.transform_values(&:size)).to eq(venues: 1, acts: 1, gigs: 1)
    expect(Venue.all).to contain_exactly(opera_house, sydney_opera_house)
    expect(Act.all).to eq [ hans ]
    expect(Gig.all).to contain_exactly(show, late_show)
    expect(show.reload.name).to eq 'Nikki Glaser: The Vegas Residency' # the show's listing, not the package's
  end

  it 'finds nothing more to do the second time' do
    described_class.call
    expect(described_class.call.values.map(&:size)).to eq [ 0, 0, 0 ]
  end
end

require 'rails_helper'

RSpec.describe RecordMerger do
  it 'moves a duplicate venue’s gigs and source IDs, fills blanks and deletes it' do
    keep = create :venue, description: nil, timezone: nil, sources: { 'ticketmaster' => 'KovZ1' }
    duplicate = create :venue, description: 'Upstairs on Cuba', timezone: 'Pacific/Auckland', sources: { 'eventfinda' => '501' }
    gig = create :gig, venue: duplicate, start_time: Time.utc(2030, 3, 7, 11), end_time: nil

    described_class.call(keep, duplicate)

    expect(Venue.exists?(duplicate.id)).to be false
    expect(gig.reload).to have_attributes(venue: keep, local_date: Date.new(2030, 3, 8)) # now on Auckland's calendar
    expect(keep.reload).to have_attributes(description: 'Upstairs on Cuba', source_ids: { 'ticketmaster' => [ 'KovZ1' ], 'eventfinda' => [ '501' ] })
  end

  it 'moves a duplicate act’s gigs without doubling up' do
    keep, duplicate = create(:act, name: 'Hans Kim'), create(:act, name: 'Hans Kim')
    both, only_duplicate = create(:gig, acts: [ keep, duplicate ]), create(:gig, acts: [ duplicate ])

    described_class.call(keep, duplicate)

    expect(keep.reload.gigs).to contain_exactly(both, only_duplicate)
    expect(both.reload.acts).to eq [ keep ]
  end

  it 'combines two listings of a gig' do
    act_a, act_b = create(:act), create(:act)
    keep = create :gig, acts: [ act_a ], ticket_url: nil, sources: { 'ticketmaster' => 'G1' }
    duplicate = create :gig, acts: [ act_a, act_b ], ticket_url: 'https://example.com/vip', sources: { 'ticketmaster' => 'G2' }

    described_class.call(keep, duplicate)

    expect(keep.reload).to have_attributes(acts: contain_exactly(act_a, act_b), ticket_url: 'https://example.com/vip',
                                           source_ids: { 'ticketmaster' => %w[G1 G2] })
  end

  it 'refuses to mix types' do
    expect { described_class.call(create(:venue), create(:act)) }.to raise_error(ArgumentError)
  end
end

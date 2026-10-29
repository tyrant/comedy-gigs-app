require 'rails_helper'

RSpec.describe TourFinder do
  include ActiveSupport::Testing::TimeHelpers

  describe '.title' do
    {
      'Greg Davies: Full Fat Legend' => 'Full Fat Legend',
      'Greg Davies - Full Fat Legend' => 'Full Fat Legend',
      'Greg Davies Full Fat Legend' => 'Full Fat Legend',
      'Full Fat Legend - Greg Davies' => 'Full Fat Legend',
      'GREG DAVIES: FULL FAT LEGEND' => 'FULL FAT LEGEND',
      'Greg Davies - Full Fat Legend  - Venue Premium Tickets' => 'Full Fat Legend',
      'Greg Davies: Full Fat Legend (Late Show)' => 'Full Fat Legend',
      'Greg Davies: "Full Fat Legend"' => 'Full Fat Legend',
      'Greg Davies « Full Fat Legend »' => 'Full Fat Legend',
      "Greg Davies - 'Full Fat Legend'" => 'Full Fat Legend',
      "Greg Davies: Legend's Return" => "Legend's Return",
      '#Greg Davies: Full Fat Legend' => 'Full Fat Legend',
      'Greg Davies and Rhod Gilbert: Two Big Lads' => 'Two Big Lads',
      'Rhod Gilbert & Greg Davies - Two Big Lads' => 'Two Big Lads',
      'Greg Davies Presents: Full Fat Legend' => 'Full Fat Legend',
      "Greg Davies's Full Fat Legend" => 'Full Fat Legend'
    }.each do |gig_name, title|
      it "finds #{title.inspect} in #{gig_name.inspect}" do
        expect(described_class.title(gig_name, 'Greg Davies')).to eq title
      end
    end

    [
      'Greg Davies', # just the act
      'Greg Davies Live', 'An Evening with Greg Davies', 'Greg Davies - UK Tour 2026', # no title in them
      'Greg Davies & Friends', # someone else alongside, and no title
      'Greg Davies (En Español)', # a note
      'Full Fat Legend' # the act isn't named
    ].each do |gig_name|
      it "finds no title in #{gig_name.inspect}" do
        expect(described_class.title(gig_name, 'Greg Davies')).to be_nil
      end
    end
  end

  describe '.key' do
    it 'leaves out "tour" and the year' do
      expect([ 'Full Fat Legend', 'Full-Fat Legend Tour', 'Full Fat Legend UK Tour 2026', 'full fat legend 2026' ]
        .map { |title| described_class.key(title) }.uniq).to eq [ 'full fat legend' ]
    end

    it 'ignores apostrophes' do
      expect(described_class.key("90'lar Kafası")).to eq described_class.key('90lar Kafası')
    end
  end

  describe '.display_name' do
    it 'picks the commonest spelling, not the shouted one' do
      expect(described_class.display_name([ 'FULL FAT LEGEND' ] * 3 + [ 'Full Fat Legend' ] * 2)).to eq 'Full Fat Legend'
      expect(described_class.display_name([ 'UH OH', 'UH OH' ])).to eq 'UH OH'
    end
  end

  describe '.call' do
    let(:greg) { create :act, name: 'Greg Davies' }
    let(:venues) { create_list :venue, 3 }

    def gig(name, venue, act: greg) = create(:gig, name:, venue:, acts: [ act ])

    it 'groups titles shared across venues into tours, and leaves runs at one venue out' do
      legend = [ gig('Greg Davies: Full Fat Legend', venues[0]), gig('Greg Davies - Full Fat Legend Tour', venues[1]) ]
      gig('Greg Davies', venues[2])
      gig('Greg Davies: Comedy Store Residency', venues[2])
      gig('Greg Davies: Comedy Store Residency', venues[2])

      expect(described_class.call).to eq(tours: 1, tour_gigs: 2)
      expect(greg.tours.map(&:name)).to eq [ 'Full Fat Legend' ]
      expect(greg.tours.first.gigs).to match_array legend
    end

    it 'keeps a tour’s ID across runs, updating its gigs, and drops tours that have gone' do
      gig('Greg Davies: Full Fat Legend', venues[0])
      gig('Greg Davies: Full Fat Legend', venues[1])
      gig('Greg Davies: The Back Catalogue', venues[0])
      old = gig('Greg Davies: The Back Catalogue', venues[1])
      described_class.call
      legend = greg.tours.find_by!(key: 'full fat legend')

      late = gig('Greg Davies: Full Fat Legend', venues[2])
      old.destroy
      travel 1.minute do
        described_class.call
      end

      expect(greg.tours.reload.map(&:id)).to eq [ legend.id ]
      expect(legend.reload.gigs).to include late
      expect(legend.updated_at).to be > legend.created_at
    end

    it 'gives each act on a shared bill the tour' do
      rhod = create :act, name: 'Rhod Gilbert'
      2.times { |i| create :gig, name: 'Greg Davies and Rhod Gilbert: Two Big Lads', venue: venues[i], acts: [ greg, rhod ] }

      described_class.call
      expect([ greg, rhod ].map { |act| act.tours.map(&:name) }).to eq [ [ 'Two Big Lads' ], [ 'Two Big Lads' ] ]
    end
  end
end

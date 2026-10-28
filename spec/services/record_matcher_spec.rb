require 'rails_helper'

RSpec.describe RecordMatcher do
  let(:matcher) { described_class.new }

  describe '#venue' do
    let!(:opera_house) { create :venue, name: 'The Opera House Wellington', city: 'Wellington', latitude: -41.2905, longitude: 174.7768, sources: { 'ticketmaster' => 'KovZ1' } }

    it 'finds the venue linked to the source’s ID' do
      expect(matcher.venue('ticketmaster', 'KovZ1', {})).to eq opera_house
    end

    it 'finds another source’s description of it nearby' do
      found = matcher.venue('eventfinda', '501', name: 'The Opera House', city: 'Wellington', latitude: -41.2903, longitude: 174.7770)
      expect(found).to eq opera_house
    end

    it 'leaves a namesake further away alone' do
      found = matcher.venue('eventfinda', '502', name: 'The Opera House', city: 'Wellington', latitude: -41.2800, longitude: 174.7768)
      expect(found).to be_nil
    end

    it 'leaves a different room in the same building alone' do
      create :venue, name: 'Wiener Stadthalle - Halle D', city: 'Wien', latitude: 48.2017, longitude: 16.3330
      found = matcher.venue('ticketmaster', 'X', name: 'Wiener Stadthalle - Halle F', city: 'Wien', latitude: 48.2017, longitude: 16.3330)
      expect(found).to be_nil
    end
  end

  describe '#act' do
    it 'finds an act by name, give or take accents and case, preferring the busier' do
      quiet = create :act, name: 'Dara Ó Briain'
      busy = create :act, name: 'DARA O BRIAIN'
      create :gig, acts: [ busy ]

      expect(matcher.act('eventfinda', 'A1', name: 'Dara O Briain')).to eq busy
      expect(quiet).to be_persisted
    end
  end

  describe '#gig' do
    let(:venue) { create :venue }
    let(:dara) { create :act, name: 'Dara Ó Briain' }
    let(:carnival) { create :act, name: 'Comedy Carnival' }
    let(:start) { Time.utc(2030, 3, 7, 7) }
    let!(:gig) { create :gig, name: 'Dara Ó Briain', venue:, acts: [ dara, carnival ], start_time: start, end_time: nil }

    def find(**data) = matcher.gig('eventfinda', 'S1', { venue:, start_time: start, name: 'Something Else', acts: [] }.merge(data))

    it 'matches a title containing the other, at about the same time' do
      expect(find(name: 'Dara O Briain Re: Creation', start_time: start + 20.minutes)).to eq gig
    end

    it 'matches a shared performer' do
      expect(find(acts: [ dara ])).to eq gig
    end

    it 'doesn’t count a shared non-performer act' do
      expect(find(acts: [ carnival ])).to be_nil
    end

    it 'keeps an early and a late show apart' do
      expect(find(name: 'Dara Ó Briain', start_time: start + 90.minutes)).to be_nil
    end

    it 'needs the same venue' do
      expect(find(name: 'Dara Ó Briain', venue: create(:venue))).to be_nil
    end
  end
end

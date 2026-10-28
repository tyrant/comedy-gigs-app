require 'rails_helper'

RSpec.describe ActMatcher do
  let!(:urzila) { create :act, name: 'Urzila Carlson' }
  let!(:dara) { create :act, name: 'Dara Ó Briain' }
  let!(:heath) { create :act, name: 'Heath Franklin' }

  def acts_in(title) = described_class.new.acts_in(title)

  it 'finds a comedian named in the title' do
    expect(acts_in('Urzila Carlson - Fatty On a Yacht')).to eq [ urzila ]
  end

  it 'ignores case, accents and punctuation' do
    expect(acts_in('DARA O BRIAIN: Re-Creation')).to eq [ dara ]
    expect(acts_in("Heath Franklin's Chopper - GOLD")).to eq [ heath ]
  end

  it 'finds several, in title order' do
    expect(acts_in('Heath Franklin & Urzila Carlson: Double Bill')).to eq [ heath, urzila ]
  end

  it 'matches whole words only' do
    create :act, name: 'Josh Wolf'
    expect(acts_in('Josh Wolfe Live')).to be_empty
  end

  describe 'acts that don’t look like people' do
    before do
      create :act, name: 'Comedy Night'
      create :act, name: 'Stand Up Comedy'
      create :act, name: 'Chopper'
    end

    it 'leaves generic names and single words alone' do
      expect(acts_in('Jokers Wild Comedy Night')).to be_empty
      expect(acts_in('Raw Meat Monday - Live Stand Up Comedy')).to be_empty
      expect(acts_in("Heath Franklin's Chopper")).to eq [ heath ]
    end
  end

  it 'prefers the busier of two acts with the same name' do
    quiet = create :act, name: 'Urzila  Carlson' # a duplicate from another listing
    create_list :gig, 2, acts: [ urzila ]
    create :gig, acts: [ quiet ]

    expect(acts_in('Urzila Carlson')).to eq [ urzila ]
  end
end

require 'rails_helper'

RSpec.describe MatchKey do
  describe '.venue' do
    it 'drops case, punctuation, filler words and the venue’s own city' do
      expect(described_class.venue('The Top-Secret Comedy Club', 'London')).to eq 'top secret comedy club'
      expect(described_class.venue('The Opera House Wellington', 'Wellington')).to eq described_class.venue('The Opera House', 'Wellington')
      expect(described_class.venue('PARK THEATRE', 'Winnipeg')).to eq described_class.venue('The Park Theatre', 'Winnipeg')
    end

    it 'keeps what tells rooms apart' do
      expect(described_class.venue('Wiener Stadthalle - Halle D', 'Wien')).not_to eq described_class.venue('Wiener Stadthalle - Halle F', 'Wien')
    end
  end

  describe '.related?' do
    it 'matches a title inside another' do
      expect(described_class.related?('Dara Ó Briain', 'Dara O Briain Re: Creation')).to be true
      expect(described_class.related?('Suites: Matt Rife: Stay Golden World Tour', 'Matt Rife: Stay Golden World Tour')).to be true
    end

    it 'doesn’t match titles that merely look alike' do
      expect(described_class.related?("John Caparulo At Jimmy Kimmel's Comedy Club", "Adam Carolla at Jimmy Kimmel's Comedy Club")).to be false
      expect(described_class.related?('Josh Wolf', 'Josh Wolfe Live')).to be false
    end
  end

  describe '.person_name?' do
    it { expect(described_class.person_name?('Urzila Carlson')).to be true }
    it { expect(described_class.person_name?('Comedy Night')).to be false }
    it { expect(described_class.person_name?('Chopper')).to be false }
  end

  describe '.package_listing?' do
    it 'spots ticket packages' do
      [ 'Nikki Glaser | Official Caesars Ticket + Hotel Packages', 'Paul Panzer - Premium Seats', 'Suites: Matt Rife',
        'Štěpán Kozub | Fast Track', 'Auld Pals - Still Game - VIP' ].each do |name|
        expect(described_class.package_listing?(name)).to be(true), name
      end
    end

    it { expect(described_class.package_listing?('Nikki Glaser & David Spade: The Vegas Residency')).to be false }
  end

  it 'measures similarity like pg_trgm' do
    expect(described_class.similarity('Park Theatre', 'PARK THEATRE')).to eq 1.0
    expect(described_class.similarity('Halle D', 'Opera House')).to be < 0.1
  end
end

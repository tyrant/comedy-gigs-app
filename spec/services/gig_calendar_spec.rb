require 'rails_helper'

RSpec.describe GigCalendar do
  let(:venue) { create :venue, name: 'The Classic', address: '321 Queen Street', city: 'Auckland' }
  let(:gig) do
    create :gig, name: 'Rose Matafeo: Live, Again; Finally', venue:,
                 start_time: Time.utc(2027, 3, 5, 7, 30), end_time: nil, ticket_url: 'https://tickets.example/rose'
  end
  let(:calendar) { described_class.new(gig, url: 'https://gigs.example/?venue=1&gig=2') }

  def unfold(ics) = ics.gsub("\r\n ", '')
  def field(name) = unfold(calendar.to_ics)[/^#{name}:(.*)\r$/, 1]

  it 'is one event, in UTC, with CRLF line endings' do
    ics = calendar.to_ics
    expect(ics).to start_with("BEGIN:VCALENDAR\r\nVERSION:2.0\r\n")
    expect(ics).to end_with("END:VEVENT\r\nEND:VCALENDAR\r\n")
    expect(ics.scan('BEGIN:VEVENT').size).to eq 1
    expect(field('UID')).to eq "gig-#{gig.id}@gigs.mikeyclarke.co.nz"
    expect(field('DTSTART')).to eq '20270305T073000Z'
  end

  it 'gives a gig without an end time the usual length' do
    expect(field('DTEND')).to eq '20270305T093000Z'

    gig.update!(end_time: Time.utc(2027, 3, 5, 10, 15))
    expect(field('DTEND')).to eq '20270305T101500Z'
  end

  it 'escapes the text and names the venue, lineup, tickets and map link' do
    gig.acts << create(:act, name: 'Rose Matafeo') << create(:act, name: 'Guy Montgomery')

    expect(field('SUMMARY')).to eq 'Rose Matafeo: Live\, Again\; Finally'
    expect(field('LOCATION')).to eq 'The Classic\, 321 Queen Street'
    expect(field('DESCRIPTION')).to eq 'With Guy Montgomery and Rose Matafeo\nTickets: https://tickets.example/rose\n' \
                                       'On the map: https://gigs.example/?venue=1&gig=2'
    expect(field('URL')).to eq 'https://gigs.example/?venue=1&gig=2'
  end

  it 'credits Skiddle for its listings' do
    gig.link_to!('skiddle', '123')
    expect(field('DESCRIPTION')).to include 'Listing from Skiddle'
  end

  it 'marks a cancelled gig' do
    gig.update!(status: 'cancelled')
    expect(field('STATUS')).to eq 'CANCELLED'
  end

  it 'folds long lines at 75 octets without splitting characters' do
    gig.update!(name: "#{'Ōtautahi comedy night ' * 8}🎤")
    lines = calendar.to_ics.split("\r\n")

    expect(lines.map(&:bytesize).max).to be <= 75
    expect(lines.all?(&:valid_encoding?)).to be true
    expect(field('SUMMARY')).to eq gig.name
  end

  it 'names the file after the gig' do
    expect(calendar.filename).to eq 'rose-matafeo-live-again-finally.ics'
  end
end

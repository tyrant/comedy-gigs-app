require 'rails_helper'

RSpec.describe 'A gig’s calendar file', type: :request do
  let(:gig) { create :gig, name: 'Late Show' }

  it 'downloads as an .ics file linking back to the gig on the map' do
    get gig_calendar_path(gig)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq 'text/calendar'
    expect(response.headers['Content-Disposition']).to include('attachment', 'filename="late-show.ics"')
    expect(response.body.gsub("\r\n ", '')).to include "URL:http://www.example.com/?gig=#{gig.id}&venue=#{gig.venue_id}"
  end

  it 'is not found for a gig that isn’t there' do
    get gig_calendar_path(gig_id: 0)
    expect(response).to have_http_status(:not_found)
  end
end

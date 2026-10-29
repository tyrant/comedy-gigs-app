# A gig's "add to calendar" file
class CalendarsController < ApplicationController
  def show
    gig = Gig.includes(:venue, :acts, :source_links).find(params[:gig_id])
    calendar = GigCalendar.new(gig, url: root_url(venue: gig.venue_id, gig: gig.id))

    send_data calendar.to_ics, type: :ics, disposition: "attachment", filename: calendar.filename
  end
end

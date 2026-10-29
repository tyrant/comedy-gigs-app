# A gig as an iCalendar file (RFC 5545), for adding to a calendar app:
# times in UTC, so no time zone data is needed, and the venue and tickets in
# the details.
class GigCalendar
  PRODUCT = "-//Gigs//gigs.mikeyclarke.co.nz//EN".freeze
  LINE_LIMIT = 75 # octets, before a line folds

  def initialize(gig, url:)
    @gig = gig
    @url = url # the gig on the map
  end

  def to_ics
    lines = [
      "BEGIN:VCALENDAR",
      "VERSION:2.0",
      "PRODID:#{PRODUCT}",
      "CALSCALE:GREGORIAN",
      "METHOD:PUBLISH",
      "BEGIN:VEVENT",
      "UID:gig-#{@gig.id}@gigs.mikeyclarke.co.nz",
      "DTSTAMP:#{utc(Time.current)}",
      "DTSTART:#{utc(@gig.start_time)}",
      "DTEND:#{utc(@gig.end_time || @gig.start_time + Gig::ASSUMED_LENGTH)}",
      "SUMMARY:#{escape(@gig.name.strip)}",
      "LOCATION:#{escape(location)}",
      "DESCRIPTION:#{escape(description)}",
      "URL:#{@url}",
      ("STATUS:CANCELLED" if @gig.status == "cancelled"),
      "END:VEVENT",
      "END:VCALENDAR"
    ].compact

    lines.map { |line| fold(line) }.join("\r\n") + "\r\n"
  end

  def filename
    "#{@gig.name.parameterize.truncate(60, omission: '').presence || 'gig'}.ics"
  end

  private

  def location
    venue = @gig.venue
    place = venue.address.presence || venue.city
    place && !place.downcase.include?(venue.name.downcase) ? "#{venue.name}, #{place}" : (place || venue.name)
  end

  def description
    acts = @gig.acts.sort_by(&:name).map(&:name)
    [
      ("With #{acts.to_sentence}" if acts.any?),
      ("Tickets: #{@gig.ticket_url}" if @gig.ticket_url.present?),
      ("Listing from Skiddle" if @gig.source_links.any? { |link| link.source == "skiddle" }), # Skiddle's terms
      "On the map: #{@url}"
    ].compact.join("\n")
  end

  def utc(time) = time.utc.strftime("%Y%m%dT%H%M%SZ")

  # Backslashes, semicolons, commas and newlines are special in text values
  def escape(text)
    text.to_s.gsub(/\r?\n|[\\;,]/) { |special| special.end_with?("\n") ? "\\n" : "\\#{special}" }
  end

  # Lines longer than 75 octets continue on lines starting with a space,
  # never splitting a multibyte character
  def fold(line)
    return line if line.bytesize <= LINE_LIMIT

    folded = [ +"" ]
    line.each_char do |char|
      limit = folded.size == 1 ? LINE_LIMIT : LINE_LIMIT - 1
      folded << +"" if folded.last.bytesize + char.bytesize > limit
      folded.last << char
    end
    folded.join("\r\n ")
  end
end

# Builds Eventfinda API events shaped like the real v2 responses (made-up content)
module EventfindaHelpers
  def eventfinda_session(id:, start:, finish: nil, cancelled: false, timezone: "Pacific/Auckland")
    {
      "id" => id, "timezone" => timezone, "is_cancelled" => cancelled,
      "datetime_start" => start,
      "datetime_end" => finish || (Time.zone.parse(start) + 2.hours).strftime("%Y-%m-%d %H:%M:%S")
    }
  end

  def eventfinda_location(id: 501, name: "The Fringe Bar", summary: "The Fringe Bar, Wellington", lat: -41.2935, lng: 174.7787, image_id: 77)
    images = image_id ? [ eventfinda_image(image_id, "locations") ] : [ eventfinda_stock_image ]
    {
      "id" => id, "name" => name, "summary" => summary, "is_venue" => true,
      "point" => { "lat" => lat, "lng" => lng },
      "images" => { "@attributes" => { "count" => 1 }, "images" => images }
    }
  end

  def eventfinda_event(id: 9001, name: "Late Night Laughs", sessions: nil, location: eventfinda_location, **attrs)
    sessions ||= [ eventfinda_session(id: 70_001, start: "2030-03-07 19:30:00") ]
    {
      "id" => id, "name" => name,
      "url" => "https://www.eventfinda.co.nz/2030/#{name.parameterize}/wellington",
      "description" => "Stand-up &amp; sketches. <b>R18</b>",
      "address" => "26 Cuba Street, Te Aro, Wellington",
      "timezone" => "Pacific/Auckland",
      "is_cancelled" => false, "is_sold_out" => false,
      "point" => location&.dig("point"),
      "location" => location,
      "category" => { "id" => 48, "name" => "Comedy" },
      "artists" => { "@attributes" => { "count" => 0 }, "artists" => [] },
      "sessions" => { "@attributes" => { "count" => sessions.size }, "sessions" => sessions }
    }.merge(attrs.transform_keys(&:to_s))
  end

  def eventfinda_page(events, count: events.size)
    { "@attributes" => { "count" => count }, "events" => events }
  end

  private

  def eventfinda_image(id, kind)
    {
      "id" => id, "is_primary" => true, "original_url" => "https://cdn.eventfinda.co.nz/uploads/#{kind}/#{id}.jpg",
      "transforms" => { "transforms" => [
        { "transformation_id" => 2, "url" => "https://cdn.eventfinda.co.nz/uploads/#{kind}/transformed/#{id}-2.jpg", "width" => 80, "height" => 80 },
        { "transformation_id" => 7, "url" => "https://cdn.eventfinda.co.nz/uploads/#{kind}/transformed/#{id}-7.jpg", "width" => 650, "height" => 280 }
      ] }
    }
  end

  def eventfinda_stock_image
    {
      "id" => nil, "is_primary" => true, "original_url" => "https://cdn.eventfinda.co.nz/uploads/locations/",
      "transforms" => { "transforms" => [
        { "transformation_id" => 7, "url" => "https://cdn.eventfinda.co.nz/images/global/sample-images/sample-images-venue-7.webp" }
      ] }
    }
  end
end

RSpec.configure { |config| config.include EventfindaHelpers }

# Builds Skiddle API events shaped like the real v1 search results (made-up content)
module SkiddleHelpers
  def skiddle_venue(id: '137901', name: 'The Laughing Cellar', town: 'Leeds', lat: '53.7997', lng: '-1.5492')
    {
      'id' => id, 'name' => name, 'address' => '12 Call Lane', 'town' => town, 'postcode_lookup' => town,
      'postcode' => 'LS1 6DT', 'region' => 'West Yorkshire', 'country' => 'GB', 'phone' => '',
      'latitude' => lat, 'longitude' => lng, 'type' => 'bar', 'rating' => '4', 'reviewCount' => '41'
    }
  end

  def skiddle_artist(id: '123584960', name: 'Freddy Quinne', spotify: 'spotify:artist:1Vpy38Qac3HJH8YBRFCRhW')
    { 'artistid' => id, 'name' => name, 'image' => "https://d1mdxzfl9p8pzo.cloudfront.net/0/#{id}_1_1024.jpg", 'spotifyartisturl' => spotify }
  end

  # Times come with +00:00 all year, as Skiddle sends them, whatever the UK clocks say
  def skiddle_event(id: '42504161', name: 'Thursday Night Laughs', start: '2030-03-07T20:00:00', finish: '2030-03-07T22:15:00',
                    venue: skiddle_venue, artists: [], cancelled: false)
    {
      'id' => id, 'listingid' => id, 'EventCode' => 'COMEDY', 'eventname' => name,
      'cancelled' => cancelled ? '1' : '0', 'cancellationDate' => '', 'cancellationType' => cancelled ? 'cancelled' : '',
      'cancellationReason' => '', 'rescheduledDate' => '',
      'venue' => venue,
      'imageurl' => "https://d31fr2pwly4c4s.cloudfront.net/f/9/7/#{id}_th.jpg",
      'largeimageurl' => "https://d31fr2pwly4c4s.cloudfront.net/f/9/7/#{id}.jpg",
      'link' => "https://www.skiddle.com/whats-on/Leeds/The-Laughing-Cellar/#{name.parameterize}/#{id}/",
      'date' => start[0, 10], 'startdate' => "#{start}+00:00", 'enddate' => finish && "#{finish}+00:00",
      'description' => 'Three of the best acts on the circuit!',
      'openingtimes' => { 'doorsopen' => start[11, 5], 'doorsclose' => finish.to_s[11, 5], 'lastentry' => start[11, 5] },
      'minage' => '18', 'tickets' => true, 'ticketpricing' => { 'minPrice' => '9.5', 'maxPrice' => '14' },
      'ticketUrl' => '', 'currency' => 'GBP', 'artists' => artists, 'genres' => []
    }
  end

  def skiddle_page(events, totalcount: events.size)
    { 'error' => 0, 'totalcount' => totalcount.to_s, 'pagecount' => events.size, 'results' => events }
  end
end

RSpec.configure { |config| config.include SkiddleHelpers }

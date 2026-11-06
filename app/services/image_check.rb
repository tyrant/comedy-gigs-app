# Keeps only the images that load. Ticketmaster France gives a photo for
# nearly every venue, but most are gone (in Nov 2026, 15 of 177 on
# website.tmaster.org loaded, and static.ticketmaster.fr no longer resolves),
# and nothing in a URL tells the live ones from the dead.
#
# Records only ever store images that loaded, so URLs a record already has are
# taken on trust; a dead one is tried again on the next run, in case it's back.
class ImageCheck
  TIMEOUT = 5 # seconds

  def initialize(adapter: nil)
    @http = Faraday.new do |f|
      f.options.timeout = TIMEOUT
      f.options.open_timeout = TIMEOUT
      f.adapter(*adapter) if adapter
    end
    @loads = {} # url -> whether it loaded, so a venue's photo is checked once a run, not once a gig
  end

  # images: { size => url }; known: the record's images so far
  def loading(images, known: {})
    return images if images.blank? || !Rails.configuration.x.check_images

    images.select { |_size, url| known.value?(url) || loads?(url) }
  end

  private

  def loads?(url)
    @loads.fetch(url) { @loads[url] = @http.head(url).status.between?(200, 399) }
  rescue Faraday::Error, URI::InvalidURIError, ArgumentError
    @loads[url] = false
  end
end

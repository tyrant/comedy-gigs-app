# How names compare across sources, which spell the same thing differently:
# "The Top-Secret Comedy Club" / "Top Secret Comedy Club", "Dara Ó Briain" /
# "DARA O BRIAIN".
module MatchKey
  # Words that don't tell venues apart
  VENUE_FILLER = %w[a an and at of the].to_set.freeze

  module_function

  # "Dara Ó Briain: Re-Creation" -> "dara o briain re creation"
  def normalize(text)
    I18n.transliterate(text.to_s).downcase.gsub(/[^a-z0-9]+/, " ").squish
  end

  def act(name) = normalize(name)

  # The name without filler or its own city: "The Opera House Wellington" and
  # Eventfinda's "The Opera House" both become "opera house". Venues sharing a
  # key are the same only when they're also close together (VenueMatcher).
  def venue(name, city)
    city_words = normalize(city).split.to_set
    normalize(name).split.reject { |word| VENUE_FILLER.include?(word) || city_words.include?(word) }.join(" ")
  end

  # Two titles for the same show: one inside the other ("Adam Kay" / "Adam
  # Kay – Twas The Nightshift Before Christmas", "Suites: Matt Rife: ..." /
  # "Matt Rife: ..."). Merely similar titles aren't enough: "John Caparulo at
  # Jimmy Kimmel's Comedy Club" and "Adam Carolla at ..." are different shows.
  def related?(a, b)
    a, b = normalize(a), normalize(b)
    return false if a.empty? || b.empty?

    " #{a} ".include?(" #{b} ") || " #{b} ".include?(" #{a} ")
  end

  # Words that make an act's name a description rather than a person's name
  GENERIC_ACT_WORDS = %w[
    cabaret club comedian comedians comedic comedy comic comics fest festival funny gala improv improvised
    joke jokes laugh laughs live mic night nights open podcast presents roast series show shows showcase
    sketch special stand standup tour
  ].to_set.freeze

  # Whether an act's name looks like a performer's ("Urzila Carlson") rather
  # than one of the listings Ticketmaster calls acts ("Comedy Night", "Stand Up
  # Comedy"), or a single word that's too easily a common one
  def person_name?(name, max_words: 5)
    words = act(name).split
    words.size.between?(2, max_words) && words.none? { |word| GENERIC_ACT_WORDS.include?(word) }
  end

  # Ticketmaster lists ticket packages alongside the show itself: "Nikki Glaser |
  # Official Caesars Ticket + Hotel Packages", "Paul Panzer - Premium Seats",
  # "Suites: Matt Rife: ...", "Štěpán Kozub | Fast Track"
  PACKAGE_LISTING = /\b(?:packages?|premium|vip|suites?|hospitality|parking|fast track)\b/i

  def package_listing?(name) = PACKAGE_LISTING.match?(name.to_s)

  # Used to list near misses for review (rake dedupe:candidates).
  # Postgres pg_trgm's measure: shared three-letter chunks over all chunks
  def similarity(a, b)
    ta, tb = trigrams(a), trigrams(b)
    return 0.0 if ta.empty? || tb.empty?

    (ta & tb).size.fdiv((ta | tb).size)
  end

  def trigrams(text)
    normalize(text).split.each_with_object(Set.new) do |word, set|
      padded = "  #{word} "
      (0..padded.length - 3).each { |i| set << padded[i, 3] }
    end
  end
end

# Works out each act's tours from its gigs' names. None of the sources mark
# tours (Ticketmaster has no tour or series field; Eventfinda and Skiddle
# neither), but listings name them consistently once the act's own name and
# the punctuation round it are gone: "Greg Davies: Full Fat Legend", "Greg
# Davies - Full Fat Legend" and "Greg Davies Full Fat Legend" are one tour.
#
# A tour is a title shared by gigs at MIN_VENUES or more venues, so a run at
# one club isn't one. Gigs named only for the act join no tour: which one
# they belong to is a guess. Tours are rebuilt whole each run, keeping their
# IDs (and so links to them) while their titles last.
class TourFinder
  MIN_VENUES = 2

  # Punctuation round a title, once the act's name is out of it
  EDGES = /\A[\s\-–—:|,.\/+~*!#&]+|[\s\-–—:|,.\/+~*!#&]+\z/

  # Ticket variants and scheduling notes after the title: "Greg Davies - Full
  # Fat Legend - Venue Premium Tickets", "... (Late Show)"
  NOISE = /
    \s*[\-–—:|(\[]?\s*\b
    (?:venue\s+)?
    (?:premium|vip|platinum|meet\s*(?:&|and)\s*greet|packages?|suites?|hospitality|fast\s+track|
       early\s+show|late\s+show|matinee|2nd\s+show|second\s+show|extra\s+(?:date|show)|new\s+date|
       rescheduled|moved|added|sold\s+out|1[68]\+|all\s+ages|tickets?)
    \b.*\z
  /ix

  # A title in quotes, of any style: "Title", « Titre », „Titel“
  QUOTED = /\A["'“”‘’«»„]\s*(.+?)\s*["'“”‘’«»„]\z/

  # Another act billed alongside, before the title: "Joe Gatto and Drew Lynch:
  # Wrap It Up Tour" leaves "and Drew Lynch: Wrap It Up Tour" for Joe Gatto,
  # and "Joe Gatto and : Wrap It Up Tour" for Drew Lynch
  LEADING = /\A[\s\-–—:|,.\/~*!#]+/
  CO_BILL = /\A(?:&|and|with|\+|x|vs\.?)\s|\s(?:&|and|with|\+|x)\s*(?::|\s[\-–—|])/i
  TITLE_AFTER = /(?::|\s[\-–—|])\s*(.+)\z/

  # Words that alone make no title: "Greg Davies Live", "An Evening with ..."
  GENERIC_WORDS = (MatchKey::GENERIC_ACT_WORDS + %w[
    a an and the in on at with of for to from by featuring feat ft plus special guest guests evening
    world uk us usa nz australia europe north american conversation q support supported presented
    en espanol 2024 2025 2026 2027 2028
  ]).to_set.freeze

  # What's left off a title to compare it: "Full Fat Legend Tour 2026" and
  # "Full Fat Legend" are one
  KEY_SUFFIX = /(?:\s+(?:the\s+)?(?:(?:uk|us|world|european|north\s+american|international)\s+)?tour)?(?:\s+20\d\d)?\z/

  def self.call = new.call

  # The title a gig's name gives the act, if any: "Greg Davies: Full Fat
  # Legend" -> "Full Fat Legend"
  def self.title(gig_name, act_name)
    act_pattern = /\b#{Regexp.escape(act_name.strip).gsub('\ ', '\s+')}\b(?:'s|’s)?/i
    rest = gig_name.to_s.gsub(act_pattern, " ")
    return nil if rest == gig_name.to_s # the act isn't named in it

    rest = rest.sub(NOISE, "").gsub(/\(\s*\)/, " ").squish.sub(LEADING, "")
    rest = rest[TITLE_AFTER, 1].to_s if rest.match?(CO_BILL) # no separator: no title of its own ("& Friends")
    rest = rest.gsub(EDGES, "").squish
    rest = rest.sub(/\Apresents\b[\s:]*/i, "")
    return nil if rest.start_with?("(") && rest.end_with?(")") # a note, not a title: "(En Español)"

    rest = rest[QUOTED, 1] || rest
    words = MatchKey.normalize(rest).split
    rest if words.any? { |word| !GENERIC_WORDS.include?(word) }
  end

  # Apostrophes go before comparing: "90'lar Kafası" and "90lar Kafası" are one
  def self.key(title) = MatchKey.normalize(title.delete("'’")).sub(KEY_SUFFIX, "").squish

  # The commonest spelling, but not SHOUTING when there's another
  def self.display_name(titles)
    ranked = titles.tally.sort_by { |title, count| [ -count, title ] }.map(&:first)
    ranked.find { |title| title != title.upcase } || ranked.first
  end

  def call
    stats = { tours: 0, tour_gigs: 0 }

    Act.includes(:tours, gigs: :venue).find_each do |act|
      found = tours_for(act)
      Tour.transaction { save(act, found) }
      stats[:tours] += found.size
      stats[:tour_gigs] += found.values.sum { |tour| tour[:gigs].size }
    end

    Rails.logger.info "Tours: #{stats[:tours]} tours, #{stats[:tour_gigs]} gigs"
    stats
  end

  private

  # { key => { name:, gigs: [...] } }
  def tours_for(act)
    by_key = Hash.new { |hash, key| hash[key] = [] }
    act.gigs.each do |gig|
      title = self.class.title(gig.name, act.name) or next
      key = self.class.key(title)
      by_key[key] << [ title, gig ] if key.present?
    end

    by_key.filter_map do |key, entries|
      gigs = entries.map(&:last)
      next if gigs.map(&:venue_id).uniq.size < MIN_VENUES

      [ key, { name: self.class.display_name(entries.map(&:first)), gigs: } ]
    end.to_h
  end

  def save(act, found)
    act.tours.each { |tour| tour.destroy unless found.key?(tour.key) }

    found.each do |key, data|
      tour = act.tours.find { |existing| existing.key == key } || act.tours.build(key:)
      tour.name = data[:name]
      gig_ids = data[:gigs].map(&:id).sort
      changed = tour.new_record? || tour.changed? || tour.gig_ids.sort != gig_ids
      tour.save!
      next unless changed

      tour.gig_ids = gig_ids
      tour.touch # cached API responses that list it go stale
    end
  end
end

# Finds a short bio for acts with gigs coming up: the opening paragraph of
# their English Wikipedia article. Ticketmaster has no descriptions for acts,
# and Eventfinda doesn't list them.
#
# Names are ambiguous ("Bill Bailey" is also an actor, "Scott Bennett" a
# rugby player), so an article only counts if Wikidata says its subject is a
# comedian. Articles are looked up by exact title, "Name" or "Name
# (comedian)", rather than searched for: search finds more but is often
# refused as "too busy". Comedians known by a stage name whose article is
# under their own name ("Tape Face" is Sam Wills) are missed.
#
# Each act is checked again after RECHECK_AFTER, found or not.
class ActBios
  # Wikidata's comedian, stand-up comedian and humorist
  COMEDY_OCCUPATIONS = %w[Q245068 Q18545066 Q12406482].freeze

  RECHECK_AFTER = 30.days
  BATCH_SIZE = 300 # acts a night; about two requests each
  MAX_ERROR_SAMPLES = 10

  def self.call(...) = new(...).call

  def initialize(client: Api::WikipediaClient.new, limit: BATCH_SIZE)
    @client = client
    @limit = limit
  end

  # Stats like an import's: successful = bios found, skipped = no comedian's article
  def call
    stats = { total_processed: 0, successful: 0, failed: 0, skipped: 0, rate_limited: 0, error_samples: [] }

    due_acts.each do |act|
      stats[:total_processed] += 1
      bio = find_bio(act.name)
      act.update!(bio: bio&.dig(:text), bio_url: bio&.dig(:url), bio_checked_at: Time.current)
      stats[bio ? :successful : :skipped] += 1
    rescue Api::RateLimitError => e
      # Wikimedia wants a rest; carry on tomorrow from here
      stats[:rate_limited] += 1
      stats[:error] = { class: e.class.name, message: e.message }
      break
    rescue StandardError => e
      stats[:failed] += 1
      stats[:error_samples] << "#{act.name}: #{e.class}: #{e.message}".truncate(300) if stats[:error_samples].size < MAX_ERROR_SAMPLES
    end

    stats
  end

  # People with gigs coming up, never checked or not lately, busiest first
  def due_acts
    upcoming = Gig.where(start_time: Time.current..).where.not(status: "cancelled")
    Act.joins(:gigs).merge(upcoming)
      .where("acts.bio_checked_at IS NULL OR acts.bio_checked_at < ?", RECHECK_AFTER.ago)
      .group(:id).order(Arel.sql("COUNT(gigs.id) DESC"), :id)
      .to_a.filter { |act| MatchKey.person_name?(act.name) } # not "Laugh Factory Las Vegas"
      .first(@limit)
  end

  private

  def find_bio(name)
    item = @client.items_for_titles([ name, "#{name} (comedian)" ]).find { |candidate| comedian?(candidate) }
    title = item&.dig("sitelinks", "enwiki", "title")
    title && @client.summary(title)
  end

  def comedian?(item)
    occupations = Array(item.dig("claims", "P106")).map { |claim| claim.dig("mainsnak", "datavalue", "value", "id") }
    occupations.intersect?(COMEDY_OCCUPATIONS)
  end
end

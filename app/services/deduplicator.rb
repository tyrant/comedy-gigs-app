# Merges records already in the database that RecordMatcher would now treat
# as one: venues first (which can bring two listings of a show to the same
# venue), then acts, then gigs. Each pair keeps the record whose details lead:
# the best-ranked source, then the one with more gigs, then the older.
#
# With dry_run, nothing changes; the pairs it would merge are listed instead.
class Deduplicator
  def self.call(dry_run: false) = new(dry_run:).call

  def initialize(dry_run: false)
    @dry_run = dry_run
    @matcher = RecordMatcher.new
  end

  # { venues: ["Keep (id) <- Duplicate (id)", ...], acts: [...], gigs: [...] }
  def call
    {
      venues: merge(venue_pairs),
      acts: merge(act_pairs),
      gigs: merge(gig_pairs)
    }
  end

  private

  def merge(pairs)
    merged = Set.new
    pairs.filter_map do |keep, duplicate|
      next if merged.include?(duplicate) || merged.include?(keep)

      merged << duplicate
      RecordMerger.call(keep, duplicate) unless @dry_run
      "#{label(keep)} <- #{label(duplicate)}"
    end
  end

  def label(record)
    detail = record.is_a?(Gig) ? " at #{record.venue.name}, #{record.start_time.utc.strftime('%F %H:%M')} UTC" : ""
    "#{record.name}#{detail} (#{record.id}; #{record.source_links.map(&:source).uniq.join('+').presence || 'no source'})"
  end

  def venue_pairs
    shared_keys = Venue.where.not(match_key: [ nil, "" ]).group(:match_key).having("COUNT(*) > 1").select(:match_key)
    # The same key can belong to venues across the world ("improv" in Brea and
    # in Denver), so each venue is paired with the best-ranked one near it
    Venue.where(match_key: shared_keys).where.not(latitude: nil).includes(:source_links).group_by(&:match_key).values.flat_map do |venues|
      ranked = rank_records(venues)
      ranked.each_with_index.filter_map do |venue, index|
        keep = ranked.first(index).find { |better| close?(better, venue) }
        [ keep, venue ] if keep
      end
    end
  end

  def act_pairs
    shared_keys = Act.where.not(match_key: [ nil, "" ]).group(:match_key).having("COUNT(*) > 1").select(:match_key)
    Act.where(match_key: shared_keys).includes(:source_links).group_by(&:match_key).values.flat_map do |acts|
      keep, *others = rank_records(acts)
      others.map { |act| [ keep, act ] }
    end
  end

  # Upcoming gigs at the same venue that match each other
  def gig_pairs
    busy = Gig.where(start_time: 1.day.ago..).group(:venue_id).having("COUNT(*) > 1").select(:venue_id)
    Gig.where(venue_id: busy, start_time: 1.day.ago..).includes(:acts, :source_links, :venue).group_by(&:venue_id).values.flat_map do |gigs|
      gigs.sort_by(&:start_time).combination(2).filter_map do |a, b|
        next if (b.start_time - a.start_time).abs > RecordMatcher::GIG_WINDOW
        next unless RecordMatcher.same_show?(a.name, a.acts, b.name, b.acts)

        rank_records([ a, b ])
      end
    end
  end

  def close?(a, b)
    Geocoder::Calculations.distance_between(a.coordinates, b.coordinates, units: :km) <= RecordMatcher::VENUE_RADIUS_KM
  end

  # Best first: a show over a ticket package, the best-ranked source, then
  # more gigs, then the oldest
  def rank_records(records)
    gig_counts = records.first.is_a?(Gig) ? {} : records.to_h { |record| [ record, record.gigs.count ] }
    records.sort_by do |record|
      package = record.is_a?(Gig) && MatchKey.package_listing?(record.name) ? 1 : 0
      best_source = record.source_links.map { |link| Api::Importer::SOURCE_PRIORITY.index(link.source) || 99 }.min || 99
      [ package, best_source, -gig_counts.fetch(record, 0), record.id ]
    end
  end
end

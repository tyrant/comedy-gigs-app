# Finds the record a source is describing: the one already linked to the
# source's ID, or failing that the same venue, act or gig as described by
# another source (or by another listing in the same one).
#
# The rules are deliberately narrow, from looking at real duplicates. Rooms in
# one building have near-identical names ("Wiener Stadthalle - Halle D" and
# "- Halle F", 112m apart), and the same show often plays twice a night
# ("Popovich Comedy Pet Theater" at 10:30pm and midnight), so a near miss is
# left for a person to review (rake dedupe:candidates) rather than merged.
class RecordMatcher
  # Venues match only by the same name, but sources can place the same venue
  # several blocks apart (Hot Water Comedy Club, Liverpool: 650m between
  # Ticketmaster and Skiddle)
  VENUE_RADIUS_KM = 1.0

  # Sources disagree a little about start times (doors or show); early and
  # late shows are further apart than this
  GIG_WINDOW = 30.minutes

  # source: the importer's source; data: the record's attributes, with :external_id
  def venue(source, external_id, data)
    Venue.linked_to(source, external_id).first || similar_venue(data)
  end

  def act(source, external_id, data)
    Act.linked_to(source, external_id).first || similar_act(data)
  end

  # data needs :venue and :start_time, and :acts if known
  def gig(source, external_id, data)
    Gig.linked_to(source, external_id).first || similar_gig(data)
  end

  # Same name once filler words and its own city are dropped, and close by
  def similar_venue(data)
    key = MatchKey.venue(data[:name], data[:city])
    return nil if key.blank? || data[:latitude].blank? || data[:longitude].blank?

    point = [ data[:latitude].to_f, data[:longitude].to_f ]
    Venue.where(match_key: key).where.not(latitude: nil)
      .map { |venue| [ venue, Geocoder::Calculations.distance_between(point, venue.coordinates, units: :km) ] }
      .select { |_, distance| distance <= VENUE_RADIUS_KM }
      .min_by { |_, distance| distance }&.first
  end

  # The same name, give or take case, accents and punctuation; the act with
  # more gigs when there's more than one
  def similar_act(data)
    key = MatchKey.act(data[:name])
    return nil if key.blank?

    Act.where(match_key: key).left_joins(:gigs).group(:id).order(Arel.sql("COUNT(gigs.id) DESC"), :id).first
  end

  # Same venue, about the same time, and the same comedian or one title inside the other
  def similar_gig(data)
    venue, start_time = data[:venue], data[:start_time]
    return nil unless venue&.persisted? && start_time

    venue.gigs.where(start_time: (start_time - GIG_WINDOW)..(start_time + GIG_WINDOW)).includes(:acts)
      .select { |gig| same_show?(gig.name, gig.acts, data[:name], Array(data[:acts])) }
      .min_by { |gig| (gig.start_time - start_time).abs }
  end

  # Ticketmaster attaches venues and series as acts ("Comedy Carnival"), which
  # two different shows can share; only performers count
  def self.same_show?(name_a, acts_a, name_b, acts_b)
    performers = (acts_a & acts_b).select { |act| MatchKey.person_name?(act.name) }
    performers.any? || MatchKey.related?(name_a, name_b)
  end

  def same_show?(*) = self.class.same_show?(*)
end

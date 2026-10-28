namespace :dedupe do
  desc "Merge duplicate venues, acts and gigs (DRY_RUN=1 to list them without merging)"
  task run: :environment do
    dry_run = ENV["DRY_RUN"].present?
    results = Deduplicator.call(dry_run:)

    results.each do |type, pairs|
      puts "#{type}: #{pairs.size} #{dry_run ? 'to merge' : 'merged'}"
      pairs.each { |pair| puts "  #{pair}" }
    end
  end

  desc "List likely duplicates the automatic rules leave alone, for review"
  task candidates: :environment do
    puts "Venues within 150m with similar names:"
    Venue.where.not(latitude: nil).to_a.group_by { |venue| [ venue.latitude.round(2), venue.longitude.round(2) ] }.values.each do |nearby|
      nearby.combination(2).each do |a, b|
        next if a.match_key == b.match_key
        next if Geocoder::Calculations.distance_between(a.coordinates, b.coordinates, units: :km) > 0.15

        similarity = MatchKey.similarity(a.name, b.name)
        puts format("  %.2f  %s (%d)  /  %s (%d)", similarity, a.name, a.id, b.name, b.id) if similarity >= 0.5
      end
    end

    puts "Acts with nearly the same name:"
    Act.pluck(:id, :name, :match_key).group_by { |_, _, key| key.to_s.split.last }.values.each do |acts|
      acts.combination(2).each do |(id_a, a, key_a), (id_b, b, key_b)|
        next if key_a == key_b

        similarity = MatchKey.similarity(a, b)
        puts format("  %.2f  %s (%d)  /  %s (%d)", similarity, a, id_a, b, id_b) if similarity >= 0.6
      end
    end

    puts "Merge a pair with: bin/rails \"dedupe:merge[venue,KEEP_ID,DUPLICATE_ID]\" (or act, gig)"
  end

  desc "Merge one record into another: dedupe:merge[venue|act|gig,keep_id,duplicate_id]"
  task :merge, %i[type keep_id duplicate_id] => :environment do |_, args|
    model = { "venue" => Venue, "act" => Act, "gig" => Gig }.fetch(args[:type]) { abort "type must be venue, act or gig" }
    keep, duplicate = model.find(args[:keep_id]), model.find(args[:duplicate_id])

    RecordMerger.call(keep, duplicate)
    puts "Merged #{duplicate.name} (#{duplicate.id}) into #{keep.name} (#{keep.id})"
  end
end

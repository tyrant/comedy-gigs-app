namespace :venues do
  # Imports only check photos they haven't stored before, so this clears out
  # dead ones stored before ImageCheck existed. Safe to rerun.
  desc "Drop venue photos that no longer load"
  task drop_dead_images: :environment do
    check = ImageCheck.new
    checked = dropped = 0

    Venue.where.not(images: {}).find_each do |venue|
      checked += 1
      live = check.loading(venue.images)
      next if live == venue.images

      dropped += 1
      venue.update!(images: live)
    end

    puts "Checked #{checked} venues with photos; dropped dead ones from #{dropped}"
  end
end

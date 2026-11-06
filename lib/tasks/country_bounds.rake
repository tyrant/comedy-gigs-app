namespace :country_bounds do
  # curl -O https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_50m_admin_0_countries.geojson
  # bin/rails "country_bounds:build[ne_50m_admin_0_countries.geojson]"
  desc "Rebuild config/country_bounds.json (CountryBounds) from Natural Earth's admin-0 countries"
  task :build, [ :geojson ] => :environment do |_task, args|
    bounds = CountryBounds.build(JSON.parse(File.read(args.fetch(:geojson)))["features"])
    File.write(CountryBounds::FILE, JSON.generate(bounds))
    puts "Wrote #{bounds.size} countries, #{bounds.values.sum(&:size)} boxes, to #{CountryBounds::FILE}"
  end
end

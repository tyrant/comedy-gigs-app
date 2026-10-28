FactoryBot.define do
  factory :venue, traits: [ :sourced ] do
    sequence(:name) { |n| "Comedy Club #{n}" }
    address { "123 Comedy Street" }
    city { "Test City" }
    country { "Test Country" }
    latitude { 35.6762 }
    longitude { 139.6503 }
  end
end

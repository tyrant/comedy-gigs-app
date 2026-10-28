FactoryBot.define do
  factory :act, traits: [ :sourced ] do
    sequence(:name) { |n| "Comedian #{n}" }
    description { "Hilarious stand-up comedian" }
    social_links { {} }
    images { {} }
  end
end

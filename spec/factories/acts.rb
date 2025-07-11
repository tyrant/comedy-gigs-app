FactoryBot.define do
  factory :act do
    sequence(:name) { |n| "Comedian #{n}" }
    description { "Hilarious stand-up comedian" }
    social_links { {} }
    external_ids { {} }
    images { {} }
  end
end

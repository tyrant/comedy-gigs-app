FactoryBot.define do
  factory :tour do
    association :act
    sequence(:name) { |n| "Tour Number #{n}" }
    key { MatchKey.normalize(name) }
  end
end

FactoryBot.define do
  factory :gig do
    sequence(:name) { |n| "Comedy Show #{n}" }
    start_time { 1.day.from_now }
    end_time { 1.day.from_now + 2.hours }
    status { 'scheduled' }
    association :venue
  end
end

# sources: { "ticketmaster" => "KovZ1" } links the record to those source IDs
FactoryBot.define do
  trait :sourced do
    transient do
      sources { {} }
    end

    after(:create) do |record, evaluator|
      evaluator.sources.each { |source, ids| Array(ids).each { |id| record.link_to!(source, id) } }
    end
  end
end

# One source's ID for a venue, act or gig
class SourceLink < ApplicationRecord
  belongs_to :linkable, polymorphic: true

  validates :source, :external_id, presence: true
end

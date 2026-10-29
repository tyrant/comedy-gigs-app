# One act's run of shows under one title, across venues ("Greg Davies: Full
# Fat Legend"). TourFinder assembles them from gig names each night.
class Tour < ApplicationRecord
  belongs_to :act
  has_and_belongs_to_many :gigs

  validates :name, :key, presence: true
end

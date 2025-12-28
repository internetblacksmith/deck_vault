class Card < ApplicationRecord
  belongs_to :card_set
  has_one :collection_card, dependent: :destroy

  validates :name, :scryfall_id, presence: true
  validates :scryfall_id, uniqueness: true
end

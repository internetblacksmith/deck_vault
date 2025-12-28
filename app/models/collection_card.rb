class CollectionCard < ApplicationRecord
  belongs_to :card

  validates :card_id, presence: true, uniqueness: true
  validates :quantity, presence: true, numericality: { greater_than_or_equal_to: 0 }
end

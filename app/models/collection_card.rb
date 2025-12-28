class CollectionCard < ApplicationRecord
  belongs_to :card

  validates :card_id, presence: true, uniqueness: true
  validates :quantity, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :page_number, numericality: { greater_than: 0, less_than_or_equal_to: 200 }, allow_nil: true
end

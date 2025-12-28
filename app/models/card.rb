class Card < ApplicationRecord
  belongs_to :card_set
  has_one :collection_card, dependent: :destroy

  validates :name, :scryfall_id, presence: true
  validates :scryfall_id, uniqueness: true

  def to_image_hash
    {
      id: scryfall_id,
      name: name,
      image_uris: JSON.parse(image_uris || "{}")
    }
  end
end

class Card < ApplicationRecord
  # Use scryfall_id (UUID) as primary key for easier backup/restore of collections
  self.primary_key = "id"

  belongs_to :card_set, touch: true
  has_one :collection_card, dependent: :destroy

  validates :name, presence: true
  validates :id, presence: true, uniqueness: true

  # Delete image file when card is destroyed
  after_destroy :delete_image_file

  # Alias for clarity - id IS the scryfall_id
  def scryfall_id
    id
  end

  # Check if this card has a back face (double-faced card)
  def double_faced?
    back_image_uris.present?
  end

  def to_image_hash
    {
      id: id,
      name: name,
      image_uris: JSON.parse(image_uris || "{}")
    }
  end

  def to_back_image_hash
    return nil unless double_faced?

    {
      id: id,
      name: name,
      image_uris: JSON.parse(back_image_uris || "{}")
    }
  end

  private

  def delete_image_file
    return if image_path.blank?

    file_path = Rails.root.join("storage", image_path)
    FileUtils.rm_f(file_path) if File.exist?(file_path)
  rescue StandardError => e
    Rails.logger.error("Error deleting image file #{image_path}: #{e.message}")
  end
end

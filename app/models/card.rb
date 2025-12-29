class Card < ApplicationRecord
  belongs_to :card_set, touch: true
  has_one :collection_card, dependent: :destroy

  validates :name, :scryfall_id, presence: true
  validates :scryfall_id, uniqueness: true

  # Delete image file when card is destroyed
  after_destroy :delete_image_file

  def to_image_hash
    {
      id: scryfall_id,
      name: name,
      image_uris: JSON.parse(image_uris || "{}")
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

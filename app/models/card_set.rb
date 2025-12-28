class CardSet < ApplicationRecord
  has_many :cards, dependent: :destroy
  validates :code, :name, presence: true
  validates :code, uniqueness: true

  enum :download_status, { pending: "pending", downloading: "downloading", completed: "completed", failed: "failed" }

  def download_progress_percentage
    return 0 if card_count.blank? || card_count.zero?
    (images_downloaded.to_f / card_count * 100).round(2)
  end

  def all_images_downloaded?
    images_downloaded >= card_count
  end
end

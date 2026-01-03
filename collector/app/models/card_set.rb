class CardSet < ApplicationRecord
  has_many :cards, dependent: :destroy

  # Parent/child set relationships
  belongs_to :parent_set, class_name: "CardSet", primary_key: "code", foreign_key: "parent_set_code", optional: true
  has_many :child_sets, class_name: "CardSet", primary_key: "code", foreign_key: "parent_set_code"

  validates :code, :name, presence: true
  validates :code, uniqueness: true

  # Enable Turbo Streams broadcasting for this model
  # Note: We handle broadcasts manually in DownloadCardImagesJob to pass total_cards
  broadcasts_to ->(card_set) { "card_set_#{card_set.id}_progress" },
                target: ->(card_set) { "progress-#{card_set.id}" },
                partial: "card_sets/images_stats_card"

  enum :download_status, { pending: "pending", downloading: "downloading", completed: "completed", failed: "failed" }

  def download_progress_percentage
    return 0 if card_count.blank? || card_count.zero?
    (images_downloaded.to_f / card_count * 100).round(2)
  end

  def all_images_downloaded?
    images_downloaded >= card_count
  end

  # Optimize collection card counts when cards are already loaded
  def cards_count
    if cards.loaded?
      cards.size
    else
      cards.count
    end
  end

  def owned_cards_count
    if cards.loaded? && cards.all? { |c| c.association(:collection_card).loaded? }
      # Use in-memory count when both cards and collection_cards are preloaded
      cards.count { |c| c.collection_card.present? && (c.collection_card.quantity.to_i > 0 || c.collection_card.foil_quantity.to_i > 0) }
    else
      # Fall back to database query
      cards.joins(:collection_card).where("collection_cards.quantity > 0 OR collection_cards.foil_quantity > 0").distinct.count
    end
  end
end

class DownloadCardImagesJob < ApplicationJob
  queue_as :default
  sidekiq_options retry: 3

  def perform(card_id)
    card = Card.find(card_id)
    card_set = card.card_set

    return if card.image_path.present? # Skip if already downloaded

    image_path = ScryfallService.download_card_image(card.to_image_hash)

    if image_path
      card.update(image_path: image_path)
      Rails.logger.info("Downloaded image for card #{card.name}")
    else
      Rails.logger.warn("Failed to download image for card #{card.name}")
    end

    # Update progress
    images_count = card_set.cards.where.not(image_path: nil).count
    card_set.update(images_downloaded: images_count)

    # Mark as completed if all images downloaded
    if card_set.images_downloaded >= card_set.card_count
      card_set.update(download_status: :completed)
      Rails.logger.info("Completed downloading all images for set #{card_set.name}")
    end
  rescue StandardError => e
    Rails.logger.error("Error downloading image for card #{card_id}: #{e.message}")
    raise
  end
end

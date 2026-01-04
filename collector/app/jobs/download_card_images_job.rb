class DownloadCardImagesJob < ApplicationJob
  queue_as :default
  sidekiq_options retry: 3

  # Small delay between image downloads to be a good citizen
  # Note: scryfall.io CDN doesn't have strict rate limits, but we're polite
  IMAGE_DOWNLOAD_DELAY = 0.05 # 50ms

  def perform(card_id)
    # Eager load card_set to avoid strict_loading violation
    card = Card.includes(:card_set).find(card_id)
    card_set = card.card_set

    # Download front image if not present
    if card.image_path.blank?
      sleep(IMAGE_DOWNLOAD_DELAY) # Rate limit
      image_path = ScryfallService.download_card_image(card.to_image_hash)

      if image_path
        card.update(image_path: image_path)
        Rails.logger.info("Downloaded front image for card #{card.name}")
      else
        Rails.logger.warn("Failed to download front image for card #{card.name}")
      end
    end

    # Download back image for double-faced cards if not present
    if card.double_faced? && card.back_image_path.blank?
      sleep(IMAGE_DOWNLOAD_DELAY) # Rate limit
      back_image_path = ScryfallService.download_card_image(card.to_back_image_hash, suffix: "_back")

      if back_image_path
        card.update(back_image_path: back_image_path)
        Rails.logger.info("Downloaded back image for card #{card.name}")
      else
        Rails.logger.warn("Failed to download back image for card #{card.name}")
      end
    end

    # Update progress
    images_count = card_set.cards.where.not(image_path: nil).count
    card_set.update(images_downloaded: images_count)

    # Broadcast Turbo Stream update for progress bar
    broadcast_progress_update(card_set, images_count)

    # Mark as completed if all images downloaded
    if card_set.images_downloaded >= card_set.card_count
      card_set.update(download_status: :completed)
      Rails.logger.info("Completed downloading all images for set #{card_set.name}")
      broadcast_completion(card_set)
    end
  rescue StandardError => e
    Rails.logger.error("Error downloading image for card #{card_id}: #{e.message}")
    raise
  end

  private

  def broadcast_progress_update(card_set, images_count)
    total_cards = card_set.cards.count

    # Use Turbo Stream to update images stats card
    Turbo::StreamsChannel.broadcast_update_to(
      "card_set_#{card_set.id}_progress",
      target: "progress-#{card_set.id}",
      partial: "card_sets/images_stats_card",
      locals: { card_set: card_set, total_cards: total_cards }
    )

    # Also keep ActionCable broadcast for legacy support
    ActionCable.server.broadcast(
      "set_progress:#{card_set.id}",
      {
        type: "progress_update",
        images_downloaded: images_count,
        card_count: card_set.card_count,
        percentage: card_set.download_progress_percentage,
        status: card_set.download_status
      }
    )
  end

  def broadcast_completion(card_set)
    total_cards = card_set.cards.count

    # Broadcast Turbo Stream completion update
    Turbo::StreamsChannel.broadcast_update_to(
      "card_set_#{card_set.id}_progress",
      target: "progress-#{card_set.id}",
      partial: "card_sets/images_stats_card",
      locals: { card_set: card_set, total_cards: total_cards }
    )

    # Also keep ActionCable broadcast for legacy support
    ActionCable.server.broadcast(
      "set_progress:#{card_set.id}",
      {
        type: "completed",
        images_downloaded: card_set.card_count,
        card_count: card_set.card_count,
        percentage: 100,
        status: "completed"
      }
    )
  end
end

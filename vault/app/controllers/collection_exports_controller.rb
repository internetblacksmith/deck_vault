# frozen_string_literal: true

# Handles collection export operations to various formats
class CollectionExportsController < ApplicationController
  # Export collection as JSON backup
  def export_collection
    collection_data = CollectionCard
      .where("quantity > 0 OR foil_quantity > 0")
      .pluck(:card_id, :quantity, :foil_quantity)
      .map { |card_id, qty, foil_qty| { card_id: card_id, quantity: qty || 0, foil_quantity: foil_qty || 0 } }

    export = {
      version: 1,
      exported_at: Time.current.iso8601,
      total_cards: collection_data.size,
      collection: collection_data
    }

    send_data export.to_json,
      filename: "mtg_collection_#{Date.current}.json",
      type: "application/json",
      disposition: "attachment"
  end

  # Export full collection data for static showcase site
  # Includes all card details, set info, and image URLs
  def export_showcase
    sets = CardSet.includes(cards: :collection_card).order(:name)

    sets_data = sets.map do |card_set|
      owned_cards = card_set.cards.select { |c| c.collection_card&.quantity.to_i > 0 || c.collection_card&.foil_quantity.to_i > 0 }
      {
        code: card_set.code,
        name: card_set.name,
        released_at: card_set.released_at,
        card_count: card_set.cards.count,
        owned_count: owned_cards.count,
        completion_percentage: card_set.cards.count > 0 ? (owned_cards.count.to_f / card_set.cards.count * 100).round(1) : 0
      }
    end

    cards_data = Card.includes(:card_set, :collection_card)
                     .joins(:collection_card)
                     .where("collection_cards.quantity > 0 OR collection_cards.foil_quantity > 0")
                     .map { |card| format_card_for_export(card) }

    total_cards = cards_data.sum { |c| c[:quantity] + c[:foil_quantity] }

    export = {
      version: 2,
      export_type: "showcase",
      exported_at: Time.current.iso8601,
      stats: {
        total_unique: cards_data.count,
        total_cards: total_cards,
        total_foils: cards_data.sum { |c| c[:foil_quantity] },
        sets_collected: sets_data.count { |s| s[:owned_count] > 0 }
      },
      sets: sets_data.select { |s| s[:owned_count] > 0 },
      cards: cards_data
    }

    send_data export.to_json,
      filename: "mtg_showcase_#{Date.current}.json",
      type: "application/json",
      disposition: "attachment"
  end

  # Export only duplicate cards (quantity > 1) for selling
  def export_duplicates
    duplicates = Card.includes(:card_set, :collection_card)
                     .joins(:collection_card)
                     .where("collection_cards.quantity > 1 OR collection_cards.foil_quantity > 1")
                     .map { |card| format_card_for_export(card, duplicates_only: true) }
                     .select { |c| c[:duplicate_quantity] > 0 || c[:duplicate_foil_quantity] > 0 }

    total_duplicates = duplicates.sum { |c| c[:duplicate_quantity] + c[:duplicate_foil_quantity] }

    export = {
      version: 1,
      export_type: "duplicates",
      exported_at: Time.current.iso8601,
      stats: {
        unique_cards_with_duplicates: duplicates.count,
        total_duplicate_cards: total_duplicates,
        total_duplicate_foils: duplicates.sum { |c| c[:duplicate_foil_quantity] }
      },
      cards: duplicates
    }

    send_data export.to_json,
      filename: "mtg_duplicates_#{Date.current}.json",
      type: "application/json",
      disposition: "attachment"
  end

  # Publish collection to GitHub Gist for Showcase site
  def publish_to_gist
    result = GistExportService.new.export

    respond_to do |format|
      if result[:success]
        format.json { render json: result }
        format.html { redirect_to card_sets_path, notice: result[:message] }
      else
        format.json { render json: result, status: :unprocessable_entity }
        format.html { redirect_to card_sets_path, alert: result[:error] }
      end
    end
  end

  private

  def format_card_for_export(card, duplicates_only: false)
    quantity = card.collection_card&.quantity.to_i
    foil_quantity = card.collection_card&.foil_quantity.to_i
    image_uris = JSON.parse(card.image_uris || "{}")
    back_image_uris = card.back_image_uris.present? ? JSON.parse(card.back_image_uris) : nil

    data = {
      id: card.id,
      name: card.name,
      set_code: card.card_set.code,
      set_name: card.card_set.name,
      collector_number: card.collector_number,
      rarity: card.rarity,
      type_line: card.type_line,
      mana_cost: card.mana_cost,
      image_url: image_uris["normal"] || image_uris["large"],
      image_url_small: image_uris["small"],
      back_image_url: back_image_uris&.dig("normal") || back_image_uris&.dig("large"),
      is_foil_available: card.foil,
      is_nonfoil_available: card.nonfoil,
      quantity: quantity,
      foil_quantity: foil_quantity
    }

    if duplicates_only
      data[:duplicate_quantity] = [ quantity - 1, 0 ].max
      data[:duplicate_foil_quantity] = [ foil_quantity - 1, 0 ].max
    end

    data
  end
end

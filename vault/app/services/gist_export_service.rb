# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

class GistExportService
  GITHUB_API_URL = "https://api.github.com"
  GIST_FILENAME = "deck_vault_collection.json"

  class Error < StandardError; end
  class ConfigurationError < Error; end
  class ApiError < Error; end

  def initialize
    @github_token = Setting.github_token
    @gist_id = Setting.showcase_gist_id
  end

  # Export collection to GitHub Gist
  # Returns { success: true, gist_url: "...", raw_url: "..." } or { success: false, error: "..." }
  def export
    validate_configuration!

    collection_data = build_collection_data

    if @gist_id.present?
      update_gist(collection_data)
    else
      create_gist(collection_data)
    end
  rescue ConfigurationError => e
    { success: false, error: e.message }
  rescue ApiError => e
    { success: false, error: "GitHub API error: #{e.message}" }
  rescue StandardError => e
    Rails.logger.error("GistExportService error: #{e.message}")
    { success: false, error: "Unexpected error: #{e.message}" }
  end

  # Get the raw URL for the Gist (for Showcase to fetch)
  def raw_url
    return nil unless @gist_id.present?

    "https://gist.githubusercontent.com/raw/#{@gist_id}/#{GIST_FILENAME}"
  end

  private

  def validate_configuration!
    raise ConfigurationError, "GITHUB_TOKEN not configured" if @github_token.blank?
  end

  def build_collection_data
    sets = CardSet.where(download_status: :completed).includes(cards: :collection_card)

    # Build flat card array (matching Showcase format)
    all_owned_cards = []
    sets_data = []

    sets.each do |set|
      set_data, owned_cards = build_set_data(set)
      sets_data << set_data
      all_owned_cards.concat(owned_cards)
    end

    {
      version: 2,
      export_type: "showcase",
      exported_at: Time.current.iso8601,
      stats: build_stats(sets, all_owned_cards),
      sets: sets_data,
      cards: all_owned_cards
    }
  end

  def build_stats(sets, owned_cards)
    total_foils = owned_cards.sum { |c| c[:foil_quantity] }
    total_cards = owned_cards.sum { |c| c[:quantity] + c[:foil_quantity] }

    {
      total_unique: owned_cards.count,
      total_cards: total_cards,
      total_foils: total_foils,
      sets_collected: sets.count
    }
  end

  def build_set_data(set)
    cards = set.cards.includes(:collection_card).order(:collector_number)
    owned_cards = cards.select { |c| c.collection_card&.quantity.to_i > 0 || c.collection_card&.foil_quantity.to_i > 0 }
    owned_cards_data = owned_cards.map { |card| build_card_data(card, set) }

    completion_pct = cards.any? ? (owned_cards.count.to_f / cards.count * 100).round(1) : 0.0

    set_data = {
      code: set.code,
      name: set.name,
      released_at: set.released_at&.to_s,
      card_count: cards.count,
      owned_count: owned_cards.count,
      completion_percentage: completion_pct
    }

    [ set_data, owned_cards_data ]
  end

  def build_card_data(card, set)
    collection = card.collection_card
    image_uris = begin
      JSON.parse(card.image_uris || "{}")
    rescue StandardError
      {}
    end
    card_faces = begin
      JSON.parse(card.card_faces || "[]")
    rescue StandardError
      []
    end

    # Get back image from card faces if available
    back_image = card_faces.length > 1 ? card_faces[1].dig("image_uris", "normal") : nil

    {
      id: card.id,
      name: card.name,
      set_code: set.code,
      set_name: set.name,
      collector_number: card.collector_number,
      rarity: card.rarity,
      type_line: card.type_line,
      mana_cost: card.mana_cost,
      image_url: image_uris["normal"] || image_uris["large"],
      image_url_small: image_uris["small"],
      back_image_url: back_image,
      is_foil_available: card.foil == true || card.foil.nil?,
      is_nonfoil_available: card.nonfoil == true || card.nonfoil.nil?,
      quantity: collection&.quantity.to_i,
      foil_quantity: collection&.foil_quantity.to_i
    }
  end

  def create_gist(data)
    response = github_request(
      method: :post,
      path: "/gists",
      body: {
        description: "Deck Vault Export - #{Time.current.strftime('%Y-%m-%d %H:%M')}",
        public: false,
        files: {
          GIST_FILENAME => {
            content: JSON.pretty_generate(data)
          }
        }
      }
    )

    gist_id = response["id"]
    raw_url = response.dig("files", GIST_FILENAME, "raw_url")

    # Auto-save the gist ID for future updates
    Setting.showcase_gist_id = gist_id

    Rails.logger.info("Created new Gist: #{gist_id}")

    {
      success: true,
      gist_id: gist_id,
      gist_url: response["html_url"],
      raw_url: raw_url,
      message: "Collection published successfully! Gist ID saved automatically."
    }
  end

  def update_gist(data)
    response = github_request(
      method: :patch,
      path: "/gists/#{@gist_id}",
      body: {
        description: "Deck Vault Export - #{Time.current.strftime('%Y-%m-%d %H:%M')}",
        files: {
          GIST_FILENAME => {
            content: JSON.pretty_generate(data)
          }
        }
      }
    )

    raw_url = response.dig("files", GIST_FILENAME, "raw_url")

    Rails.logger.info("Updated Gist: #{@gist_id}")

    {
      success: true,
      gist_id: @gist_id,
      gist_url: response["html_url"],
      raw_url: raw_url,
      message: "Collection published successfully!"
    }
  end

  def github_request(method:, path:, body: nil)
    uri = URI("#{GITHUB_API_URL}#{path}")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = case method
    when :post
      Net::HTTP::Post.new(uri)
    when :patch
      Net::HTTP::Patch.new(uri)
    when :get
      Net::HTTP::Get.new(uri)
    else
      raise ArgumentError, "Unsupported HTTP method: #{method}"
    end

    request["Authorization"] = "Bearer #{@github_token}"
    request["Accept"] = "application/vnd.github+json"
    request["User-Agent"] = "DeckVault/1.0"
    request["X-GitHub-Api-Version"] = "2022-11-28"

    if body
      request["Content-Type"] = "application/json"
      request.body = body.to_json
    end

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      error_message = begin
        JSON.parse(response.body)["message"]
      rescue
        response.body
      end
      raise ApiError, "#{response.code}: #{error_message}"
    end

    JSON.parse(response.body)
  end
end

class ScryfallService
  BASE_URL = "https://api.scryfall.com".freeze

  # Fetch all Magic: The Gathering sets
  def self.fetch_sets
    response = HTTParty.get("#{BASE_URL}/sets")
    return [] unless response.success?

    response.parsed_response["data"].map { |set_data| format_set(set_data) }
  rescue StandardError => e
    Rails.logger.error("Error fetching sets from Scryfall: #{e.message}")
    []
  end

  # Fetch all cards for a specific set
  def self.fetch_cards_for_set(set_code)
    cards = []
    page = 1
    has_more = true

    while has_more
      response = HTTParty.get("#{BASE_URL}/cards/search", query: { q: "set:#{set_code}", page: page, unique: "cards" })
      break unless response.success?

      cards.concat(response.parsed_response["data"].map { |card_data| format_card(card_data) })
      has_more = response.parsed_response["has_more"] || false
      page += 1
    end

    cards
  rescue StandardError => e
    Rails.logger.error("Error fetching cards for set #{set_code}: #{e.message}")
    []
  end

  # Format set data for database
  def self.format_set(set_data)
    {
      code: set_data["code"],
      name: set_data["name"],
      released_at: set_data["released_at"],
      card_count: set_data["card_count"],
      scryfall_uri: set_data["scryfall_uri"]
    }
  end

  # Format card data for database
  def self.format_card(card_data)
    {
      name: card_data["name"],
      mana_cost: card_data["mana_cost"],
      type_line: card_data["type_line"],
      oracle_text: card_data["oracle_text"],
      rarity: card_data["rarity"],
      scryfall_id: card_data["id"],
      image_uris: card_data["image_uris"].to_json,
      collector_number: card_data["collector_number"]
    }
  end

  # Download and save a set to the database
  def self.download_set(set_code)
    card_set = CardSet.find_or_create_by(code: set_code) do |set|
      set_data = fetch_set_details(set_code)
      set.name = set_data["name"]
      set.released_at = set_data["released_at"]
      set.card_count = set_data["card_count"]
      set.scryfall_uri = set_data["scryfall_uri"]
    end

    # Fetch and save cards for this set
    cards_data = fetch_cards_for_set(set_code)
    cards_data.each do |card_data|
      Card.find_or_create_by(scryfall_id: card_data[:scryfall_id]) do |card|
        card.card_set = card_set
        card.assign_attributes(card_data)
      end
    end

    card_set
  rescue StandardError => e
    Rails.logger.error("Error downloading set #{set_code}: #{e.message}")
    nil
  end

  # Fetch details for a specific set
  def self.fetch_set_details(set_code)
    response = HTTParty.get("#{BASE_URL}/sets/#{set_code}")
    return {} unless response.success?

    response.parsed_response
  rescue StandardError => e
    Rails.logger.error("Error fetching set details for #{set_code}: #{e.message}")
    {}
  end
end

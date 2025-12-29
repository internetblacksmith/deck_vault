class ScryfallService
  BASE_URL = "https://api.scryfall.com".freeze
  IMAGES_DIR = Rails.root.join("storage/card_images").freeze

  # Ensure images directory exists
  def self.ensure_images_dir
    FileUtils.mkdir_p(IMAGES_DIR) unless File.exist?(IMAGES_DIR)
  end

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
      response = HTTParty.get("#{BASE_URL}/cards/search", query: { q: "set:#{set_code}", page: page })
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
      scryfall_uri: set_data["scryfall_uri"],
      set_type: set_data["set_type"],
      parent_set_code: set_data["parent_set_code"]
    }
  end

  # Group sets by parent (main sets with their children)
  def self.group_sets(sets)
    # Separate parent sets and child sets
    parent_sets = sets.select { |s| s[:parent_set_code].nil? }
    child_sets = sets.select { |s| s[:parent_set_code].present? }

    # Build lookup of children by parent code
    children_by_parent = child_sets.group_by { |s| s[:parent_set_code] }

    # Build grouped structure
    parent_sets.map do |parent|
      {
        **parent,
        children: children_by_parent[parent[:code]] || []
      }
    end
  end

  # Format card data for database (without downloading image)
  # Handles both normal cards and double-faced cards (DFCs)
  def self.format_card(card_data)
    {
      name: card_data["name"],
      mana_cost: card_data["mana_cost"],
      type_line: card_data["type_line"],
      oracle_text: card_data["oracle_text"],
      rarity: card_data["rarity"],
      scryfall_id: card_data["id"],
      image_uris: extract_image_uris(card_data).to_json,
      collector_number: card_data["collector_number"],
      image_path: nil  # Will be set by background job
    }
  end

  # Extract image_uris from card data, handling double-faced cards
  # DFCs have image_uris in card_faces[0] instead of at the top level
  def self.extract_image_uris(card_data)
    # Normal cards have image_uris at top level
    return card_data["image_uris"] if card_data["image_uris"].present?

    # Double-faced cards have image_uris in card_faces
    if card_data["card_faces"].present? && card_data["card_faces"][0]["image_uris"].present?
      return card_data["card_faces"][0]["image_uris"]
    end

    # Fallback: no image available
    nil
  end

  # Download card image and return local path
  # card_data comes from Card#to_image_hash (symbol keys) or raw Scryfall API (string keys)
  def self.download_card_image(card_data)
    ensure_images_dir

    # Support both symbol and string keys
    image_uris = card_data[:image_uris] || card_data["image_uris"]
    return nil unless image_uris && (image_uris["normal"] || image_uris[:normal])

    image_url = image_uris["normal"] || image_uris[:normal]
    scryfall_id = card_data[:id] || card_data["id"]

    # Create filename from scryfall ID and card name
    filename = "#{scryfall_id}.jpg"
    filepath = IMAGES_DIR.join(filename)

    # Skip if already downloaded
    return "card_images/#{filename}" if File.exist?(filepath)

    begin
      # Download image
      response = HTTParty.get(image_url, timeout: 30)

      if response.success?
        File.open(filepath, "wb") { |f| f.write(response.body) }
        Rails.logger.info("Downloaded card image: #{filename}")
        "card_images/#{filename}"
      else
        Rails.logger.warn("Failed to download image from #{image_url}")
        nil
      end
    rescue StandardError => e
      Rails.logger.error("Error downloading card image #{filename}: #{e.message}")
      nil
    end
  end

  # Download and save a set to the database (without images)
  def self.download_set(set_code)
    card_set = CardSet.find_or_create_by(code: set_code) do |set|
      set_data = fetch_set_details(set_code)
      set.name = set_data["name"]
      set.released_at = set_data["released_at"]
      set.card_count = set_data["card_count"]
      set.scryfall_uri = set_data["scryfall_uri"]
      set.set_type = set_data["set_type"]
      set.parent_set_code = set_data["parent_set_code"]
    end

    # Fetch and save cards for this set
    cards_data = fetch_cards_for_set(set_code)
    cards_data.each do |card_data|
      card = Card.find_or_create_by(scryfall_id: card_data[:scryfall_id]) do |c|
        c.card_set = card_set
        c.assign_attributes(card_data)
      end

      # Queue image download as background job
      DownloadCardImagesJob.perform_later(card.id) if card.persisted? && card.image_path.blank?
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

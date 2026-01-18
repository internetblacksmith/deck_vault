class ScryfallService
  BASE_URL = "https://api.scryfall.com".freeze
  IMAGES_DIR = Rails.root.join("storage/card_images").freeze

  # Required headers per Scryfall API Terms of Service
  # https://scryfall.com/docs/api
  HEADERS = {
    "User-Agent" => "MTGCollector/1.0 (https://github.com/jabawack81/mtg_collector)",
    "Accept" => "application/json"
  }.freeze

  # Rate limit delay between API requests (Scryfall recommends 50-100ms)
  RATE_LIMIT_DELAY = 0.1 # 100ms = 10 requests/second max

  # Ensure images directory exists
  def self.ensure_images_dir
    FileUtils.mkdir_p(IMAGES_DIR) unless File.exist?(IMAGES_DIR)
  end

  # Fetch all Magic: The Gathering sets
  def self.fetch_sets
    response = HTTParty.get("#{BASE_URL}/sets", headers: HEADERS)
    return [] unless response.success?

    response.parsed_response["data"].map { |set_data| format_set(set_data) }
  rescue StandardError => e
    Rails.logger.error("Error fetching sets from Scryfall: #{e.message}")
    []
  end

  # Fetch all cards for a specific set
  # Uses unique:prints to get all card variants (including full-art, showcase, etc.)
  # Implements rate limiting per Scryfall ToS (50-100ms between requests)
  def self.fetch_cards_for_set(set_code)
    cards = []
    page = 1
    has_more = true

    while has_more
      # Rate limit: wait between paginated requests (not needed for first page)
      sleep(RATE_LIMIT_DELAY) if page > 1

      response = HTTParty.get("#{BASE_URL}/cards/search", query: { q: "set:#{set_code} unique:prints", page: page }, headers: HEADERS)
      break unless response.success?

      cards.concat(response.parsed_response["data"].map { |card_data| format_card(card_data) })
      has_more = response.parsed_response["has_more"] || false
      page += 1

      # Log progress for large sets
      Rails.logger.info("Fetched page #{page - 1} for set #{set_code} (#{cards.size} cards so far)") if page > 2
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
  # Note: id is the Scryfall UUID, used as primary key
  def self.format_card(card_data)
    front_uris, back_uris = extract_image_uris(card_data)
    {
      id: card_data["id"],  # Scryfall UUID as primary key
      name: card_data["name"],
      mana_cost: card_data["mana_cost"],
      type_line: card_data["type_line"],
      oracle_text: card_data["oracle_text"],
      rarity: card_data["rarity"],
      image_uris: front_uris&.to_json,
      back_image_uris: back_uris&.to_json,
      collector_number: card_data["collector_number"],
      image_path: nil,  # Will be set by background job
      back_image_path: nil,  # Will be set by background job for DFCs
      foil: card_data.fetch("foil", false),
      nonfoil: card_data.fetch("nonfoil", true)
    }
  end

  # Extract image_uris from card data, handling double-faced cards
  # Returns [front_uris, back_uris] - back_uris is nil for single-faced cards
  def self.extract_image_uris(card_data)
    # Normal cards have image_uris at top level (no back face)
    if card_data["image_uris"].present?
      return [ card_data["image_uris"], nil ]
    end

    # Double-faced cards have image_uris in card_faces
    if card_data["card_faces"].present?
      front_uris = card_data["card_faces"][0]["image_uris"]
      back_uris = card_data["card_faces"][1]["image_uris"] if card_data["card_faces"].length > 1
      return [ front_uris, back_uris ]
    end

    # Fallback: no image available
    [ nil, nil ]
  end

  # Download card image and return local path
  # card_data comes from Card#to_image_hash (symbol keys) or raw Scryfall API (string keys)
  # suffix: optional suffix for filename (e.g., "_back" for back face of DFCs)
  def self.download_card_image(card_data, suffix: "")
    ensure_images_dir

    return nil if card_data.nil?

    # Support both symbol and string keys
    image_uris = card_data[:image_uris] || card_data["image_uris"]
    return nil unless image_uris && (image_uris["normal"] || image_uris[:normal])

    image_url = image_uris["normal"] || image_uris[:normal]
    scryfall_id = card_data[:id] || card_data["id"]

    # Create filename from scryfall ID with optional suffix
    filename = "#{scryfall_id}#{suffix}.jpg"
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
  # If include_children is true, also downloads all child sets (promos, tokens, etc.)
  def self.download_set(set_code, include_children: true)
    card_set = download_single_set(set_code)
    return nil unless card_set

    # Download child sets if this is a parent set
    if include_children
      child_sets = fetch_child_sets(set_code)
      child_sets.each do |child_code|
        child_set = download_single_set(child_code)
        child_set&.update(download_status: :downloading)
      end
    end

    card_set
  rescue StandardError => e
    Rails.logger.error("Error downloading set #{set_code}: #{e.message}")
    nil
  end

  # Download a single set without children
  def self.download_single_set(set_code)
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
      card = Card.find_or_create_by(id: card_data[:id]) do |c|
        c.card_set = card_set
        c.assign_attributes(card_data.except(:id))
      end

      # Queue image download as background job
      DownloadCardImagesJob.perform_later(card.id) if card.persisted? && card.image_path.blank?
    end

    card_set
  rescue StandardError => e
    Rails.logger.error("Error downloading single set #{set_code}: #{e.message}")
    nil
  end

  # Fetch all child set codes for a given parent set code
  def self.fetch_child_sets(parent_code)
    all_sets = fetch_sets
    all_sets.select { |s| s[:parent_set_code] == parent_code }.map { |s| s[:code] }
  rescue StandardError => e
    Rails.logger.error("Error fetching child sets for #{parent_code}: #{e.message}")
    []
  end

  # Fetch details for a specific set
  def self.fetch_set_details(set_code)
    response = HTTParty.get("#{BASE_URL}/sets/#{set_code}", headers: HEADERS)
    return {} unless response.success?

    response.parsed_response
  rescue StandardError => e
    Rails.logger.error("Error fetching set details for #{set_code}: #{e.message}")
    {}
  end

  # Refresh cards for an existing set - adds new cards without losing collection data
  # Returns hash with :added and :updated counts
  def self.refresh_set(card_set)
    cards_data = fetch_cards_for_set(card_set.code)
    return { added: 0, updated: 0, images_queued: 0, error: "Failed to fetch cards from Scryfall" } if cards_data.empty?

    added = 0
    updated = 0
    images_queued = 0

    cards_data.each do |card_data|
      existing_card = card_set.cards.find_by(id: card_data[:id])

      if existing_card
        # Update existing card (but preserve image_path if already downloaded)
        update_attrs = card_data.except(:id, :image_path)
        update_attrs[:image_uris] = card_data[:image_uris] if card_data[:image_uris].present?
        existing_card.update(update_attrs)
        updated += 1
        # Queue image download for existing card if missing
        if existing_card.image_path.blank?
          DownloadCardImagesJob.perform_later(existing_card.id)
          images_queued += 1
        end
      else
        # Create new card
        card = card_set.cards.create(card_data)
        if card.persisted?
          added += 1
          # Queue image download for new card
          if card.image_path.blank?
            DownloadCardImagesJob.perform_later(card.id)
            images_queued += 1
          end
        end
      end
    end

    # Update set metadata
    set_details = fetch_set_details(card_set.code)
    if set_details.present?
      card_set.update(
        card_count: set_details["card_count"],
        name: set_details["name"]
      )
    end

    { added: added, updated: updated, images_queued: images_queued }
  rescue StandardError => e
    Rails.logger.error("Error refreshing set #{card_set.code}: #{e.message}")
    { added: 0, updated: 0, error: e.message }
  end
end

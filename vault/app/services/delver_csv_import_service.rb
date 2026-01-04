# frozen_string_literal: true

require "csv"

# Service to import collection data from Delver Lens CSV exports
# Delver Lens exports include Scryfall IDs which we use for matching
#
# Expected CSV columns:
# - Name: Card name
# - Edition code: Set code (e.g., "TLA")
# - Collector's number: Card number in set
# - QuantityX: Quantity string (e.g., "2x")
# - Foil: Empty or "Foil" for foil cards
# - Scryfall ID: UUID matching our card IDs
#
# Modes:
# - :add (default) - Add imported quantities to existing collection
# - :replace - Replace existing quantities with imported values
#
# Auto-downloads missing sets from Scryfall before importing
class DelverCsvImportService
  MODES = %i[add replace].freeze

  Result = Struct.new(:success?, :imported, :foils_imported, :skipped, :errors, :missing_sets, :downloaded_sets, keyword_init: true)

  def initialize(csv_content, mode: :add)
    @csv_content = csv_content
    @mode = MODES.include?(mode&.to_sym) ? mode.to_sym : :add
    @errors = []
    @imported = 0
    @foils_imported = 0
    @skipped = 0
    @missing_sets = Set.new
    @downloaded_sets = []
  end

  def import
    parse_and_import
    Result.new(
      success?: @errors.empty? || @imported > 0,
      imported: @imported,
      foils_imported: @foils_imported,
      skipped: @skipped,
      errors: @errors,
      missing_sets: @missing_sets.to_a,
      downloaded_sets: @downloaded_sets
    )
  end

  private

  def parse_and_import
    rows = CSV.parse(@csv_content, headers: true, liberal_parsing: true)

    if rows.empty?
      @errors << "CSV file is empty"
      return
    end

    # Check if this looks like a Delver Lens export
    unless rows.headers.include?("Scryfall ID") || rows.headers.include?("scryfall_id")
      @errors << "CSV doesn't appear to be a Delver Lens export (missing Scryfall ID column)"
      return
    end

    # First pass: collect unique set codes and download missing sets
    download_missing_sets(rows)

    # Second pass: process rows and import cards
    rows.each_with_index do |row, index|
      process_row(row, index + 2) # +2 because row 1 is header, index is 0-based
    rescue StandardError => e
      @errors << "Row #{index + 2}: #{e.message}"
    end
  rescue CSV::MalformedCSVError => e
    @errors << "CSV parsing error: #{e.message}"
  end

  def download_missing_sets(rows)
    # Collect unique set codes from CSV
    set_codes = rows.map do |row|
      (row["Edition code"] || row["edition_code"] || row["Set"] || "").downcase
    end.reject(&:blank?).uniq

    # Find which sets are missing from the database
    existing_codes = CardSet.where(code: set_codes).pluck(:code)
    missing_codes = set_codes - existing_codes

    return if missing_codes.empty?

    Rails.logger.info("Delver import: downloading #{missing_codes.count} missing sets: #{missing_codes.join(', ')}")

    # Download each missing set from Scryfall
    missing_codes.each do |set_code|
      begin
        Rails.logger.info("Downloading set #{set_code} from Scryfall...")
        card_set = ScryfallService.download_set(set_code, include_children: false)

        if card_set
          @downloaded_sets << { code: set_code, name: card_set.name, card_count: card_set.cards.count }
          Rails.logger.info("Downloaded set #{set_code}: #{card_set.name} (#{card_set.cards.count} cards)")
        else
          @errors << "Failed to download set '#{set_code}' from Scryfall"
        end
      rescue StandardError => e
        @errors << "Error downloading set '#{set_code}': #{e.message}"
        Rails.logger.error("Error downloading set #{set_code}: #{e.message}")
      end
    end
  end

  def process_row(row, row_number)
    # Extract Scryfall ID (primary matching method)
    scryfall_id = row["Scryfall ID"] || row["scryfall_id"] || ""
    name = row["Name"] || row["name"] || ""
    edition_code = row["Edition code"] || row["edition_code"] || row["Set"] || ""
    collector_number = row["Collector's number"] || row["collector_number"] || ""
    quantity_str = row["QuantityX"] || row["Quantity"] || row["quantity"] || "1x"
    foil_value = row["Foil"] || row["foil"] || ""

    # Skip empty rows
    return if name.blank? && scryfall_id.blank?

    # Parse quantity (e.g., "2x" -> 2)
    quantity = parse_quantity(quantity_str)

    # Determine if foil - check for "Foil" or any truthy non-"false" value
    is_foil = foil_value.present? && foil_value.to_s.strip.downcase != "false"

    # Debug logging for foil detection
    if foil_value.present?
      Rails.logger.info("Delver import: #{name} - Foil column value: '#{foil_value}', is_foil: #{is_foil}")
    end

    # Try to find the card
    card = find_card(scryfall_id, name, edition_code, collector_number)

    unless card
      @skipped += 1
      @missing_sets << edition_code if edition_code.present?
      Rails.logger.debug("Could not find card: #{name} (#{edition_code} ##{collector_number}) - Scryfall ID: #{scryfall_id}")
      return
    end

    # Update or create collection card
    update_collection(card, quantity, is_foil)

    if is_foil
      @foils_imported += quantity
    else
      @imported += quantity
    end
  end

  def parse_quantity(str)
    return 1 if str.blank?

    # Handle "2x", "2", "x2" formats
    match = str.to_s.match(/(\d+)/)
    match ? match[1].to_i : 1
  end

  def find_card(scryfall_id, name, edition_code, collector_number)
    # Include both associations to avoid strict_loading errors
    eager_load_scope = Card.includes(:collection_card, :card_set)

    # Priority 1: Match by Scryfall ID (most reliable)
    if scryfall_id.present?
      card = eager_load_scope.find_by(id: scryfall_id)
      return card if card
    end

    # Priority 2: Match by set code + collector number
    if edition_code.present? && collector_number.present?
      card = eager_load_scope
                 .where(card_sets: { code: edition_code.downcase })
                 .where(collector_number: collector_number.to_s)
                 .first
      return card if card
    end

    # Priority 3: Match by name + set code
    if name.present? && edition_code.present?
      # Handle double-faced card names "Front // Back"
      search_name = name.split(" // ").first.strip

      card = eager_load_scope
                 .where(card_sets: { code: edition_code.downcase })
                 .where("cards.name = ? OR cards.name LIKE ?", name, "#{search_name} //%")
                 .first
      return card if card
    end

    # Priority 4: Match by name only (any set) - last resort
    if name.present?
      search_name = name.split(" // ").first.strip
      eager_load_scope
          .where("cards.name = ? OR cards.name LIKE ?", name, "#{search_name} //%")
          .first
    end
  end

  def update_collection(card, quantity, is_foil)
    collection_card = card.collection_card || CollectionCard.new(card: card)

    if @mode == :replace
      # Replace mode: set exact quantities from CSV
      if is_foil
        collection_card.foil_quantity = quantity
      else
        collection_card.quantity = quantity
      end
    else
      # Add mode: add to existing quantities
      if is_foil
        collection_card.foil_quantity = (collection_card.foil_quantity || 0) + quantity
      else
        collection_card.quantity = (collection_card.quantity || 0) + quantity
      end
    end

    unless collection_card.save
      @errors << "Failed to save #{card.name}: #{collection_card.errors.full_messages.join(', ')}"
    end
  end
end

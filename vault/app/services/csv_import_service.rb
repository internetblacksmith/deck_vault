require "csv"

class CsvImportService
  Result = Struct.new(:success, :imported, :skipped, :errors, keyword_init: true)

  def initialize(card_set, csv_content)
    @card_set = card_set
    @csv_content = csv_content
    @imported = []
    @skipped = []
    @errors = []
  end

  def import
    parse_and_import
    Result.new(
      success: @errors.empty?,
      imported: @imported,
      skipped: @skipped,
      errors: @errors
    )
  end

  private

  def parse_and_import
    # Detect delimiter (tab or comma)
    delimiter = @csv_content.include?("\t") ? "\t" : ","

    rows = CSV.parse(@csv_content, col_sep: delimiter, headers: true, liberal_parsing: true)

    rows.each_with_index do |row, index|
      process_row(row, index + 2) # +2 because row 1 is header, index is 0-based
    rescue StandardError => e
      @errors << "Row #{index + 2}: #{e.message}"
    end
  rescue CSV::MalformedCSVError => e
    @errors << "CSV parsing error: #{e.message}"
  end

  def process_row(row, row_number)
    # Extract data from row (handle different column name formats)
    quantity_str = row["QuantityX"] || row["Quantity"] || row["quantity"] || "1x"
    name = row["Name"] || row["name"] || ""
    edition = row["Edition"] || row["Set"] || row["edition"] || row["set"] || ""
    collector_number = row["Collector's number"] || row["Collector Number"] || row["collector_number"] || ""
    foil_value = row["Foil"] || row["foil"] || ""

    # Skip empty rows
    return if name.blank?

    # Parse quantity (e.g., "2x" -> 2)
    quantity = parse_quantity(quantity_str)

    # Check if this is for our card set
    unless edition_matches?(@card_set, edition)
      @skipped << { row: row_number, name: name, reason: "Edition '#{edition}' doesn't match set '#{@card_set.name}'" }
      return
    end

    # Find the card
    card = find_card(name, collector_number)

    unless card
      @skipped << { row: row_number, name: name, reason: "Card not found in set" }
      return
    end

    # Determine if foil
    is_foil = foil_value.present? && foil_value.to_s.strip.downcase != "false"

    # Update or create collection card
    update_collection(card, quantity, is_foil)

    @imported << { row: row_number, name: card.name, quantity: quantity, foil: is_foil }
  end

  def parse_quantity(str)
    return 1 if str.blank?

    # Handle "2x", "2", "x2" formats
    match = str.to_s.match(/(\d+)/)
    match ? match[1].to_i : 1
  end

  def edition_matches?(card_set, edition)
    return true if edition.blank? # If no edition specified, assume it matches

    set_name = card_set.name.downcase.strip
    edition_lower = edition.downcase.strip

    # Direct match
    return true if set_name == edition_lower

    # Match by code
    return true if card_set.code.downcase == edition_lower

    # Only match if set_name contains edition AND they're similar length
    # This prevents "Avatar: The Last Airbender" from matching "Avatar: The Last Airbender Eternal"
    if edition_lower.include?(set_name)
      # Edition is longer, check if it's just the base name
      return true if edition_lower == set_name
    end

    if set_name.include?(edition_lower)
      # Set name is longer, allow if edition matches start
      return true if set_name.start_with?(edition_lower) && (set_name.length - edition_lower.length) < 5
    end

    false
  end

  def find_card(name, collector_number)
    # Clean up name (handle double-faced cards "Front // Back")
    search_name = name.split(" // ").first.strip

    # Try exact match by collector number first (most reliable)
    if collector_number.present?
      card = @card_set.cards.find_by(collector_number: collector_number.to_s)
      return card if card
    end

    # Try by name (exact match)
    card = @card_set.cards.find_by(name: name)
    return card if card

    # Try by partial name (for double-faced cards)
    card = @card_set.cards.find_by("name LIKE ?", "#{search_name}%")
    return card if card

    # Try case-insensitive
    card = @card_set.cards.find_by("LOWER(name) = ?", search_name.downcase)
    return card if card

    nil
  end

  def update_collection(card, quantity, is_foil)
    collection_card = card.collection_card || CollectionCard.new(card: card)

    if is_foil
      collection_card.foil_quantity = (collection_card.foil_quantity || 0) + quantity
    else
      collection_card.quantity = (collection_card.quantity || 0) + quantity
    end

    collection_card.save!
  end
end

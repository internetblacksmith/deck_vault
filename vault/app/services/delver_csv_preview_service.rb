# frozen_string_literal: true

require "csv"

# Service to preview Delver Lens CSV imports without committing changes
# Returns structured data about what would be imported
class DelverCsvPreviewService
  Result = Struct.new(
    :success?,
    :cards,
    :total_count,
    :regular_count,
    :foil_count,
    :unique_count,
    :found_sets,
    :missing_sets,
    :errors,
    keyword_init: true
  )

  CardPreview = Struct.new(:name, :set_code, :set_name, :collector_number, :quantity, :foil, :found, keyword_init: true)

  def initialize(csv_content)
    @csv_content = csv_content
    @errors = []
    @cards = []
    @found_sets = {}
    @missing_sets = Set.new
  end

  def preview
    parse_csv
    Result.new(
      success?: @errors.empty? || @cards.any?,
      cards: @cards,
      total_count: @cards.sum { |c| c.quantity },
      regular_count: @cards.reject(&:foil).sum { |c| c.quantity },
      foil_count: @cards.select(&:foil).sum { |c| c.quantity },
      unique_count: @cards.size,
      found_sets: @found_sets,
      missing_sets: @missing_sets.to_a,
      errors: @errors
    )
  end

  private

  def parse_csv
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

    # Collect all set codes first
    set_codes = rows.map do |row|
      (row["Edition code"] || row["edition_code"] || row["Set"] || "").downcase
    end.reject(&:blank?).uniq

    # Check which sets exist in database
    existing_sets = CardSet.where(code: set_codes).pluck(:code, :name).to_h
    missing_codes = set_codes - existing_sets.keys

    # Track found and missing sets
    @found_sets = existing_sets
    @missing_sets = missing_codes.to_set

    # Process each row
    rows.each_with_index do |row, index|
      process_row(row, index + 2)
    rescue StandardError => e
      @errors << "Row #{index + 2}: #{e.message}"
    end
  rescue CSV::MalformedCSVError => e
    @errors << "CSV parsing error: #{e.message}"
  end

  def process_row(row, _row_number)
    scryfall_id = row["Scryfall ID"] || row["scryfall_id"] || ""
    name = row["Name"] || row["name"] || ""
    edition_code = (row["Edition code"] || row["edition_code"] || row["Set"] || "").downcase
    collector_number = row["Collector's number"] || row["collector_number"] || ""
    quantity_str = row["QuantityX"] || row["Quantity"] || row["quantity"] || "1x"
    foil_value = row["Foil"] || row["foil"] || ""

    # Skip empty rows
    return if name.blank? && scryfall_id.blank?

    quantity = parse_quantity(quantity_str)
    is_foil = foil_value.present? && foil_value.to_s.strip.downcase != "false"

    # Check if card exists in database
    card_found = card_exists?(scryfall_id, name, edition_code, collector_number)

    # Get set name if available
    set_name = @found_sets[edition_code] || edition_code.upcase

    @cards << CardPreview.new(
      name: name,
      set_code: edition_code.upcase,
      set_name: set_name,
      collector_number: collector_number,
      quantity: quantity,
      foil: is_foil,
      found: card_found || @missing_sets.include?(edition_code)
    )
  end

  def parse_quantity(str)
    return 1 if str.blank?

    match = str.to_s.match(/(\d+)/)
    match ? match[1].to_i : 1
  end

  def card_exists?(scryfall_id, name, edition_code, collector_number)
    # Priority 1: Match by Scryfall ID
    if scryfall_id.present?
      return true if Card.exists?(id: scryfall_id)
    end

    # Priority 2: Match by set code + collector number
    if edition_code.present? && collector_number.present?
      return true if Card.joins(:card_set)
                         .where(card_sets: { code: edition_code })
                         .where(collector_number: collector_number.to_s)
                         .exists?
    end

    # Priority 3: Match by name + set code
    if name.present? && edition_code.present?
      search_name = name.split(" // ").first.strip
      return true if Card.joins(:card_set)
                         .where(card_sets: { code: edition_code })
                         .where("cards.name = ? OR cards.name LIKE ?", name, "#{search_name} //%")
                         .exists?
    end

    false
  end
end

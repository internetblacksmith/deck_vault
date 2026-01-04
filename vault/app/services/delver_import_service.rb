# frozen_string_literal: true

require "sqlite3"
require "tempfile"

# Service to import collection data from Delver Lens .dlens backup files
# The .dlens file is a SQLite database containing card entries with:
# - card: internal Delver card ID (NOT Scryfall ID)
# - scryfall_id: Scryfall ID (often empty in older backups)
# - foil: 0 or 1
# - quantity: number of copies
# - list: which list/collection the card belongs to
#
# IMPORTANT: .dlens files often don't contain card names - only internal IDs.
# If scryfall_id is empty, we cannot match cards to our database.
# In this case, users should export as CSV from Delver Lens instead.
class DelverImportService
  Result = Struct.new(:success?, :imported, :foils_imported, :skipped, :errors, keyword_init: true)

  def initialize(dlens_file)
    @dlens_file = dlens_file
    @errors = []
    @imported = 0
    @foils_imported = 0
    @skipped = 0
  end

  def import
    # Write uploaded file to temp file for SQLite to read
    temp_file = Tempfile.new([ "dlens", ".db" ])
    begin
      temp_file.binmode
      temp_file.write(@dlens_file.read)
      temp_file.close

      process_database(temp_file.path)
    rescue SQLite3::Exception => e
      @errors << "SQLite error: #{e.message}"
    rescue StandardError => e
      @errors << "Import error: #{e.message}"
      Rails.logger.error("Delver import error: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
    ensure
      temp_file.unlink
    end

    Result.new(
      success?: @errors.empty?,
      imported: @imported,
      foils_imported: @foils_imported,
      skipped: @skipped,
      errors: @errors
    )
  end

  private

  def process_database(db_path)
    db = SQLite3::Database.new(db_path)
    db.results_as_hash = true

    # First, check what tables exist
    tables = db.execute("SELECT name FROM sqlite_master WHERE type='table'").map { |r| r["name"] }
    Rails.logger.info("Delver database tables: #{tables.join(', ')}")

    # The main cards table in .dlens files
    # Try different possible table names
    cards_table = find_cards_table(db, tables)

    unless cards_table
      @errors << "Could not find cards table in .dlens file. Tables found: #{tables.join(', ')}"
      return
    end

    # Get the schema to understand the columns
    schema = db.execute("PRAGMA table_info(#{cards_table})")
    columns = schema.map { |col| col["name"] }
    Rails.logger.info("Cards table columns: #{columns.join(', ')}")

    # Check if there's a separate cards metadata table (for name, set info)
    cards_meta_table = tables.find { |t| t.downcase.include?("card") && t != cards_table }

    if cards_meta_table
      import_with_metadata(db, cards_table, cards_meta_table)
    else
      import_without_metadata(db, cards_table, columns)
    end

    db.close
  end

  def find_cards_table(db, tables)
    # Common table names in Delver backups
    candidates = %w[cards collection entries items card_entries]
    candidates.each do |name|
      return name if tables.include?(name)
    end

    # Try to find a table with quantity column
    tables.each do |table|
      next if table.start_with?("sqlite_")
      schema = db.execute("PRAGMA table_info(#{table})")
      columns = schema.map { |col| col["name"].downcase }
      return table if columns.include?("quantity") || columns.include?("count")
    end

    # Return first non-system table as fallback
    tables.reject { |t| t.start_with?("sqlite_") || t == "android_metadata" }.first
  end

  def import_with_metadata(db, cards_table, meta_table)
    # This handles the case where card names/sets are in a separate table
    Rails.logger.info("Importing with metadata table: #{meta_table}")

    # Try to join the tables
    query = <<-SQL
      SELECT c.*, m.name, m.set_code, m.collector_number
      FROM #{cards_table} c
      LEFT JOIN #{meta_table} m ON c.card = m.id OR c.card_id = m.id
      WHERE c.quantity > 0 OR c.count > 0
    SQL

    begin
      rows = db.execute(query)
      process_rows(rows)
    rescue SQLite3::Exception
      # Fallback to simple import
      import_without_metadata(db, cards_table, [])
    end
  end

  def import_without_metadata(db, cards_table, columns)
    Rails.logger.info("Importing from table: #{cards_table}")

    # Get all rows with quantity > 0
    qty_col = columns.include?("quantity") ? "quantity" : "count"
    query = "SELECT * FROM #{cards_table} WHERE #{qty_col} > 0"

    begin
      rows = db.execute(query)
      process_rows(rows)
    rescue SQLite3::Exception => e
      # Try without WHERE clause
      Rails.logger.warn("Query failed, trying without filter: #{e.message}")
      rows = db.execute("SELECT * FROM #{cards_table}")
      process_rows(rows)
    end
  end

  def process_rows(rows)
    Rails.logger.info("Processing #{rows.count} rows from Delver database")

    # Check if any rows have scryfall_id populated
    has_scryfall_ids = rows.any? { |r| r["scryfall_id"].present? }

    unless has_scryfall_ids
      @errors << "This .dlens backup doesn't contain Scryfall IDs. " \
                 "Please export your collection as CSV from Delver Lens instead, " \
                 "or ensure your Delver Lens app is synced with Scryfall data."
      Rails.logger.warn("No scryfall_id found in any rows. Cannot import.")
      return
    end

    # Group by card to aggregate quantities
    card_quantities = {}

    rows.each do |row|
      # Extract card identifier - could be name, scryfall_id, or internal ID
      card_key = extract_card_key(row)
      next unless card_key

      quantity = (row["quantity"] || row["count"] || 1).to_i
      is_foil = (row["foil"] || 0).to_i == 1

      card_quantities[card_key] ||= { quantity: 0, foil_quantity: 0, row: row }
      if is_foil
        card_quantities[card_key][:foil_quantity] += quantity
      else
        card_quantities[card_key][:quantity] += quantity
      end
    end

    Rails.logger.info("Found #{card_quantities.count} unique cards")

    # Now match and import each card
    card_quantities.each do |card_key, data|
      import_card(card_key, data[:quantity], data[:foil_quantity], data[:row])
    end
  end

  def extract_card_key(row)
    # Try different ways to identify the card
    # Priority: scryfall_id > name+set > name

    if row["scryfall_id"].present?
      return { type: :scryfall_id, value: row["scryfall_id"] }
    end

    if row["name"].present?
      return {
        type: :name_set,
        name: row["name"],
        set_code: row["set_code"] || row["edition"] || row["set"],
        collector_number: row["collector_number"] || row["number"]
      }
    end

    # If we only have internal ID, we can't match without metadata
    if row["card"].present? && !row["name"].present?
      Rails.logger.debug("Row has only internal ID, skipping: #{row['card']}")
      return nil
    end

    nil
  end

  def import_card(card_key, quantity, foil_quantity, row)
    card = find_card(card_key)

    unless card
      @skipped += 1
      name = card_key.is_a?(Hash) ? (card_key[:name] || card_key[:value]) : card_key
      Rails.logger.debug("Could not find card: #{name}")
      return
    end

    # Find or create collection card
    collection_card = CollectionCard.find_or_initialize_by(card_id: card.id)
    collection_card.card = card

    # Add to existing quantities (don't replace)
    collection_card.quantity = (collection_card.quantity || 0) + quantity
    collection_card.foil_quantity = (collection_card.foil_quantity || 0) + foil_quantity

    if collection_card.save
      @imported += quantity
      @foils_imported += foil_quantity
    else
      @errors << "Failed to save #{card.name}: #{collection_card.errors.full_messages.join(', ')}"
    end
  end

  def find_card(card_key)
    case card_key[:type]
    when :scryfall_id
      Card.find_by(id: card_key[:value])
    when :name_set
      find_by_name_and_set(card_key[:name], card_key[:set_code], card_key[:collector_number])
    else
      nil
    end
  end

  def find_by_name_and_set(name, set_code, collector_number)
    # Try exact match with set and collector number first
    if set_code.present? && collector_number.present?
      card = Card.joins(:card_set)
                 .where(card_sets: { code: set_code.downcase })
                 .where(collector_number: collector_number.to_s)
                 .first
      return card if card
    end

    # Try by name and set
    if set_code.present?
      card = Card.joins(:card_set)
                 .where(card_sets: { code: set_code.downcase })
                 .where("cards.name = ? OR cards.name LIKE ?", name, "#{name} //%")
                 .first
      return card if card
    end

    # Try by name only (any set)
    Card.where("name = ? OR name LIKE ?", name, "#{name} //%").first
  end
end

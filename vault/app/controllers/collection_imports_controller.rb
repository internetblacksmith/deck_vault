# frozen_string_literal: true

# Handles collection import operations from various sources
class CollectionImportsController < ApplicationController
  include FileUploadable

  # Import from JSON backup file(s)
  def import_collection
    files = params[:backup_files]
    files ||= params[:backup_file] ? [ params[:backup_file] ] : []

    if files.empty?
      redirect_to card_sets_path, alert: "Please select at least one backup file to import"
      return
    end

    validation = validate_uploads(files, allowed_extensions: [ ".json" ])
    unless validation[:valid]
      redirect_to card_sets_path, alert: validation[:errors].first
      return
    end

    total_imported = 0
    total_skipped = 0
    all_errors = []

    files.each do |file|
      result = import_json_file(file)
      total_imported += result[:imported]
      total_skipped += result[:skipped]
      all_errors.concat(result[:errors])
    end

    render_import_result(total_imported, total_skipped, all_errors)
  end

  # Import from Delver Lens .dlens backup file (SQLite format)
  # Note: Often fails because .dlens files don't contain Scryfall IDs
  # Recommend using import_delver_csv instead
  def import_delver
    unless params[:dlens_file].present?
      redirect_to card_sets_path, alert: "Please select a .dlens backup file to import"
      return
    end

    file = params[:dlens_file]

    validation = validate_upload(file, allowed_extensions: [ ".dlens" ])
    unless validation[:valid]
      redirect_to card_sets_path, alert: validation[:error]
      return
    end

    result = DelverImportService.new(file).import

    if result.success?
      message = "Imported #{result.imported} cards (#{result.foils_imported} foils)"
      message += ", skipped #{result.skipped} (not found in database)" if result.skipped > 0
      redirect_to card_sets_path, notice: message
    else
      error_msg = "Import failed: #{result.errors.first(3).join(', ')}"
      error_msg += "..." if result.errors.count > 3
      redirect_to card_sets_path, alert: error_msg
    end
  end

  # Import from Delver Lens CSV export (recommended method)
  # Supports multiple files at once
  def import_delver_csv
    files = params[:csv_files]
    files ||= params[:csv_file] ? [ params[:csv_file] ] : []

    if files.empty?
      redirect_to card_sets_path, alert: "Please select at least one CSV file to import"
      return
    end

    validation = validate_uploads(files, allowed_extensions: [ ".csv" ])
    unless validation[:valid]
      redirect_to card_sets_path, alert: validation[:errors].first
      return
    end

    mode = params[:import_mode]&.to_sym || :add
    total_imported = 0
    total_foils_imported = 0
    total_skipped = 0
    all_errors = []
    all_downloaded_sets = []
    all_missing_sets = Set.new

    files.each do |file|
      unless file.original_filename.end_with?(".csv")
        all_errors << "#{file.original_filename}: Please upload CSV files only"
        next
      end

      begin
        csv_content = file.read.force_encoding("UTF-8")
        result = DelverCsvImportService.new(csv_content, mode: mode).import

        if result.success?
          total_imported += result.imported
          total_foils_imported += result.foils_imported
          total_skipped += result.skipped
          all_downloaded_sets.concat(result.downloaded_sets)
          all_missing_sets.merge(result.missing_sets)
        else
          all_errors.concat(result.errors)
        end
      rescue StandardError => e
        all_errors << "#{file.original_filename}: #{e.message}"
      end
    end

    render_delver_csv_result(mode, total_imported, total_foils_imported, total_skipped, all_errors, all_downloaded_sets, all_missing_sets)
  end

  # Preview Delver CSV import without committing changes
  # Returns JSON with preview data for modal display
  def preview_delver_csv
    files = params[:csv_files]
    files ||= params[:csv_file] ? [ params[:csv_file] ] : []

    if files.empty?
      render json: { success: false, error: "Please select at least one CSV file" }, status: :unprocessable_entity
      return
    end

    validation = validate_uploads(files, allowed_extensions: [ ".csv" ])
    unless validation[:valid]
      render json: { success: false, errors: validation[:errors] }, status: :unprocessable_entity
      return
    end

    all_cards = []
    all_errors = []
    found_sets = {}
    missing_sets = Set.new

    files.each do |file|
      unless file.original_filename.end_with?(".csv")
        all_errors << "#{file.original_filename}: Please upload CSV files only"
        next
      end

      begin
        csv_content = file.read.force_encoding("UTF-8")
        result = DelverCsvPreviewService.new(csv_content).preview

        if result.success?
          all_cards.concat(result.cards)
          found_sets.merge!(result.found_sets)
          missing_sets.merge(result.missing_sets)
        else
          all_errors.concat(result.errors.map { |e| "#{file.original_filename}: #{e}" })
        end
      rescue StandardError => e
        all_errors << "#{file.original_filename}: #{e.message}"
      end
    end

    if all_cards.empty? && all_errors.any?
      render json: { success: false, errors: all_errors }, status: :unprocessable_entity
      return
    end

    render_preview_json(all_cards, found_sets, missing_sets, all_errors)
  end

  private

  def import_json_file(file)
    result = { imported: 0, skipped: 0, errors: [] }

    begin
      backup_data = JSON.parse(file.read)
      collection = backup_data["collection"]

      unless collection.is_a?(Array)
        result[:errors] << "#{file.original_filename}: Invalid backup file format"
        return result
      end

      collection.each do |item|
        card_id = item["card_id"]
        quantity = item["quantity"].to_i
        foil_quantity = item["foil_quantity"].to_i

        # Must preload card_set to avoid strict loading violation when touch: true triggers
        card = Card.includes(:card_set).find_by(id: card_id)
        unless card
          result[:skipped] += 1
          next
        end

        collection_card = CollectionCard.find_or_initialize_by(card_id: card_id)
        collection_card.card = card
        collection_card.quantity = quantity
        collection_card.foil_quantity = foil_quantity

        if collection_card.save
          result[:imported] += 1
        else
          result[:skipped] += 1
        end
      end
    rescue JSON::ParserError
      result[:errors] << "#{file.original_filename}: Invalid JSON file"
    rescue StandardError => e
      Rails.logger.error("Collection import error: #{e.message}")
      result[:errors] << "#{file.original_filename}: #{e.message}"
    end

    result
  end

  def render_import_result(total_imported, total_skipped, all_errors)
    if total_imported > 0
      message = "Restored #{total_imported} cards"
      message += ", skipped #{total_skipped} (cards not in database)" if total_skipped > 0
      redirect_to card_sets_path, notice: message
    elsif all_errors.any?
      error_msg = "Import failed: #{all_errors.first(3).join('; ')}"
      error_msg += "..." if all_errors.count > 3
      redirect_to card_sets_path, alert: error_msg
    else
      redirect_to card_sets_path, alert: "No valid backup files provided"
    end
  end

  def render_delver_csv_result(mode, total_imported, total_foils_imported, total_skipped, all_errors, all_downloaded_sets, all_missing_sets)
    if total_imported > 0 || total_foils_imported > 0 || total_skipped > 0
      mode_text = mode == :replace ? "Replaced with" : "Added"
      message = "#{mode_text} #{total_imported} cards"
      message += " (#{total_foils_imported} foils)" if total_foils_imported > 0
      message += ", skipped #{total_skipped}" if total_skipped > 0

      total_cards_affected = total_imported + total_foils_imported
      if mode == :add && total_cards_affected > 0
        message += ". #{total_cards_affected} cards marked NEW for binder placement"
      end

      if all_downloaded_sets.any?
        set_names = all_downloaded_sets.map { |s| s[:name] }.uniq
        message += ". Downloaded #{set_names.count} set(s): #{set_names.first(3).join(', ')}"
        message += "..." if set_names.count > 3
      end

      if all_missing_sets.any?
        message += ". Could not find sets: #{all_missing_sets.to_a.first(3).join(', ')}"
        message += "..." if all_missing_sets.count > 3
      end

      if mode == :replace && total_cards_affected > 0
        flash[:alert] = "Replace mode: Cards were NOT marked for binder placement"
      end

      redirect_to card_sets_path, notice: message
    elsif all_errors.any?
      error_msg = "Import failed: #{all_errors.first(3).join('; ')}"
      error_msg += "..." if all_errors.count > 3
      redirect_to card_sets_path, alert: error_msg
    else
      redirect_to card_sets_path, alert: "No valid CSV files provided"
    end
  end

  def render_preview_json(all_cards, found_sets, missing_sets, all_errors)
    cards_by_set = all_cards.group_by(&:set_code).transform_values do |cards|
      {
        set_name: cards.first.set_name,
        missing: missing_sets.include?(cards.first.set_code.downcase),
        cards: cards.first(50).map { |c| { name: c.name, quantity: c.quantity, foil: c.foil } },
        total_cards: cards.size,
        truncated: cards.size > 50
      }
    end

    render json: {
      success: true,
      total_count: all_cards.sum(&:quantity),
      regular_count: all_cards.reject(&:foil).sum(&:quantity),
      foil_count: all_cards.select(&:foil).sum(&:quantity),
      unique_count: all_cards.size,
      found_sets: found_sets.values.uniq,
      missing_sets: missing_sets.to_a.map(&:upcase),
      cards_by_set: cards_by_set,
      truncated: all_cards.size > 500,
      errors: all_errors
    }
  end
end

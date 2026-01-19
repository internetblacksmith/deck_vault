# frozen_string_literal: true

# Validates uploaded files for size and type
module FileUploadable
  extend ActiveSupport::Concern

  # Maximum upload size: 10MB
  MAX_UPLOAD_SIZE = 10.megabytes

  # Allowed extensions and their MIME types
  ALLOWED_TYPES = {
    ".json" => %w[application/json text/plain],
    ".csv" => %w[text/csv text/plain application/csv application/octet-stream],
    ".dlens" => %w[application/octet-stream application/x-sqlite3]
  }.freeze

  private

  def validate_upload(file, allowed_extensions:)
    return { valid: false, error: "No file provided" } unless file.present?

    # Check file size
    if file.size > MAX_UPLOAD_SIZE
      max_mb = MAX_UPLOAD_SIZE / 1.megabyte
      return { valid: false, error: "File too large (max #{max_mb}MB)" }
    end

    # Check extension
    extension = File.extname(file.original_filename).downcase
    unless allowed_extensions.include?(extension)
      return { valid: false, error: "Invalid file type. Allowed: #{allowed_extensions.join(', ')}" }
    end

    # Check MIME type
    allowed_mimes = ALLOWED_TYPES[extension]
    unless allowed_mimes&.include?(file.content_type)
      Rails.logger.warn("Unexpected MIME type #{file.content_type} for #{extension} file")
      # Allow it anyway if extension matches - MIME detection can be unreliable
    end

    { valid: true }
  end

  def validate_uploads(files, allowed_extensions:)
    errors = []

    files.each do |file|
      result = validate_upload(file, allowed_extensions: allowed_extensions)
      errors << "#{file.original_filename}: #{result[:error]}" unless result[:valid]
    end

    errors.empty? ? { valid: true } : { valid: false, errors: errors }
  end
end

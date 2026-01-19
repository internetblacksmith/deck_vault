class ImagesController < ApplicationController
  IMAGES_DIR = Rails.root.join("storage/card_images").freeze

  # Valid filename pattern: UUID with optional _back suffix and .jpg extension
  # Example: 12345678-1234-1234-1234-123456789012.jpg or 12345678-1234-1234-1234-123456789012_back.jpg
  VALID_FILENAME_PATTERN = /\A[a-f0-9\-]+(_back)?\.jpg\z/i

  def show
    filename = params[:filename]

    # Validate filename format to prevent path traversal
    unless filename.match?(VALID_FILENAME_PATTERN)
      head :bad_request
      return
    end

    # Use File.basename to strip any directory components (defense in depth)
    safe_filename = File.basename(filename)
    filepath = IMAGES_DIR.join(safe_filename)

    # Verify the resolved path is within the images directory
    unless filepath.to_s.start_with?(IMAGES_DIR.to_s)
      head :bad_request
      return
    end

    if File.exist?(filepath)
      send_file filepath, type: "image/jpeg", disposition: "inline", cache_control: "public, max-age=31536000"
    else
      head :not_found
    end
  end
end

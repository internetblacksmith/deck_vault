class ImagesController < ApplicationController
  def show
    filename = params[:filename]
    filepath = Rails.root.join("storage/card_images/#{filename}")

    if File.exist?(filepath)
      send_file filepath, type: "image/jpeg", disposition: "inline", cache_control: "public, max-age=31536000"
    else
      render file: "#{Rails.root}/public/404.html", status: 404, layout: false
    end
  end
end

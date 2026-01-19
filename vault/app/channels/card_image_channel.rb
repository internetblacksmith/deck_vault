class CardImageChannel < ApplicationCable::Channel
  def subscribed
    card_id = params[:card_id]
    stream_from "card_image:#{card_id}"
  end

  def unsubscribed
    # Cleanup handled automatically
  end
end

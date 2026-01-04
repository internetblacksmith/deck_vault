class SetProgressChannel < ApplicationCable::Channel
  def subscribed
    card_set_id = params[:card_set_id]
    stream_from "set_progress:#{card_set_id}"
  end

  def unsubscribed
    # Cleanup handled automatically
  end
end

# frozen_string_literal: true

class ChatController < ApplicationController
  def index
    # Chat page
  end

  def create
    user_message = params[:message]
    history_param = params[:history]

    # Handle both string and array history
    conversation_history = if history_param.is_a?(String) && history_param.present?
      JSON.parse(history_param)
    elsif history_param.is_a?(Array)
      history_param.map(&:to_h)
    else
      []
    end

    # Add user message to history
    conversation_history << { role: "user", content: user_message }

    begin
      service = ChatService.new
      result = service.chat(conversation_history)

      render json: {
        response: result[:response],
        history: result[:messages]
      }
    rescue StandardError => e
      Rails.logger.error("Chat error: #{e.message}")
      render json: {
        response: "Sorry, I encountered an error: #{e.message}",
        history: conversation_history
      }, status: :internal_server_error
    end
  end
end

# frozen_string_literal: true

# Service to fetch available models from the Anthropic API
class AnthropicModelsService
  API_URL = "https://api.anthropic.com/v1/models"
  API_VERSION = "2023-06-01"

  # Fallback models if API is unavailable or no API key configured
  FALLBACK_MODELS = [
    { id: "claude-sonnet-4-20250514", display_name: "Claude Sonnet 4" },
    { id: "claude-3-5-sonnet-20241022", display_name: "Claude 3.5 Sonnet" },
    { id: "claude-3-5-haiku-20241022", display_name: "Claude 3.5 Haiku" },
    { id: "claude-3-opus-20240229", display_name: "Claude 3 Opus" }
  ].freeze

  def initialize(api_key: nil)
    @api_key = api_key || Setting.anthropic_api_key
  end

  # Fetch available models from Anthropic API
  # Returns array of hashes with :id and :display_name
  def fetch_models
    return fallback_models unless @api_key.present?

    response = make_request
    return fallback_models unless response.is_a?(Net::HTTPSuccess)

    parse_models(response.body)
  rescue StandardError => e
    Rails.logger.error("Failed to fetch Anthropic models: #{e.message}")
    fallback_models
  end

  # Get models suitable for chat (filters out non-chat models)
  def chat_models
    models = fetch_models
    # Filter to only include Claude models that support messages API
    models.select { |m| m[:id].start_with?("claude-") && !m[:id].include?("instant") }
  end

  private

  def make_request
    uri = URI(API_URL)
    uri.query = URI.encode_www_form(limit: 100)

    request = Net::HTTP::Get.new(uri)
    request["x-api-key"] = @api_key
    request["anthropic-version"] = API_VERSION
    request["Content-Type"] = "application/json"

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 5
    http.read_timeout = 10

    http.request(request)
  end

  def parse_models(body)
    data = JSON.parse(body)
    models = data["data"] || []

    models.map do |model|
      {
        id: model["id"],
        display_name: model["display_name"] || model["id"]
      }
    end.sort_by { |m| m[:display_name] }
  rescue JSON::ParserError => e
    Rails.logger.error("Failed to parse Anthropic models response: #{e.message}")
    fallback_models
  end

  def fallback_models
    FALLBACK_MODELS.dup
  end
end

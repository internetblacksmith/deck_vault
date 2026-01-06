# frozen_string_literal: true

class SettingsController < ApplicationController
  def index
    @github_token_configured = Setting.github_token.present?
    @gist_id = Setting.showcase_gist_id
    @anthropic_api_key_configured = Setting.anthropic_api_key.present?
    @chat_model = Setting.chat_model
    @available_models = fetch_available_models
  end

  private

  def fetch_available_models
    AnthropicModelsService.new.chat_models
  rescue StandardError => e
    Rails.logger.error("Failed to fetch models: #{e.message}")
    AnthropicModelsService::FALLBACK_MODELS
  end

  public

  def update
    github_token = params[:github_token]
    anthropic_api_key = params[:anthropic_api_key]
    chat_model = params[:chat_model]

    messages = []

    # Handle GitHub token
    if params.key?(:github_token)
      if github_token.present?
        Setting.github_token = github_token
        messages << "GitHub token saved"
      else
        Setting.delete(Setting::GITHUB_TOKEN)
        messages << "GitHub token removed"
      end
    end

    # Handle Anthropic API key
    if params.key?(:anthropic_api_key)
      if anthropic_api_key.present?
        Setting.anthropic_api_key = anthropic_api_key
        messages << "Anthropic API key saved"
      else
        Setting.delete(Setting::ANTHROPIC_API_KEY)
        messages << "Anthropic API key removed"
      end
    end

    # Handle chat model
    if params.key?(:chat_model)
      if chat_model.present? && chat_model != Setting::DEFAULT_CHAT_MODEL
        Setting.chat_model = chat_model
        messages << "Chat model updated to #{chat_model}"
      else
        Setting.delete(Setting::CHAT_MODEL)
        messages << "Chat model reset to default"
      end
    end

    flash[:notice] = messages.any? ? messages.join(". ") + "." : "No changes made."
    redirect_to settings_path
  end

  def clear_gist_id
    Setting.delete(Setting::SHOWCASE_GIST_ID)
    flash[:notice] = "Gist ID cleared. Next publish will create a new Gist."
    redirect_to settings_path
  end
end

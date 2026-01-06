# frozen_string_literal: true

require "rails_helper"

RSpec.describe AnthropicModelsService do
  let(:api_key) { "test-api-key" }
  let(:service) { described_class.new(api_key: api_key) }

  describe "#fetch_models" do
    context "without API key" do
      let(:service) { described_class.new(api_key: nil) }

      before do
        allow(Setting).to receive(:anthropic_api_key).and_return(nil)
      end

      it "returns fallback models" do
        models = service.fetch_models

        expect(models).to eq(AnthropicModelsService::FALLBACK_MODELS)
      end
    end

    context "with API key and successful response" do
      let(:api_response) do
        {
          "data" => [
            { "id" => "claude-sonnet-4-20250514", "display_name" => "Claude Sonnet 4" },
            { "id" => "claude-3-5-sonnet-20241022", "display_name" => "Claude 3.5 Sonnet" },
            { "id" => "claude-3-opus-20240229", "display_name" => "Claude 3 Opus" }
          ]
        }.to_json
      end

      before do
        stub_request(:get, "https://api.anthropic.com/v1/models?limit=100")
          .with(
            headers: {
              "X-Api-Key" => api_key,
              "Anthropic-Version" => "2023-06-01"
            }
          )
          .to_return(status: 200, body: api_response, headers: { "Content-Type" => "application/json" })
      end

      it "returns models from API sorted by display name" do
        models = service.fetch_models

        expect(models.length).to eq(3)
        expect(models.first[:display_name]).to eq("Claude 3 Opus")
        expect(models.last[:display_name]).to eq("Claude Sonnet 4")
      end

      it "includes model id and display_name" do
        models = service.fetch_models

        expect(models.first).to include(:id, :display_name)
        expect(models.first[:id]).to eq("claude-3-opus-20240229")
      end
    end

    context "with API error" do
      before do
        stub_request(:get, "https://api.anthropic.com/v1/models?limit=100")
          .to_return(status: 500, body: "Internal Server Error")
      end

      it "returns fallback models" do
        models = service.fetch_models

        expect(models).to eq(AnthropicModelsService::FALLBACK_MODELS)
      end
    end

    context "with network error" do
      before do
        stub_request(:get, "https://api.anthropic.com/v1/models?limit=100")
          .to_raise(Errno::ECONNREFUSED)
      end

      it "returns fallback models" do
        models = service.fetch_models

        expect(models).to eq(AnthropicModelsService::FALLBACK_MODELS)
      end
    end

    context "with invalid JSON response" do
      before do
        stub_request(:get, "https://api.anthropic.com/v1/models?limit=100")
          .to_return(status: 200, body: "not json", headers: { "Content-Type" => "application/json" })
      end

      it "returns fallback models" do
        models = service.fetch_models

        expect(models).to eq(AnthropicModelsService::FALLBACK_MODELS)
      end
    end
  end

  describe "#chat_models" do
    let(:api_response) do
      {
        "data" => [
          { "id" => "claude-sonnet-4-20250514", "display_name" => "Claude Sonnet 4" },
          { "id" => "claude-3-5-haiku-20241022", "display_name" => "Claude 3.5 Haiku" },
          { "id" => "claude-instant-1.2", "display_name" => "Claude Instant" },
          { "id" => "some-other-model", "display_name" => "Other Model" }
        ]
      }.to_json
    end

    before do
      stub_request(:get, "https://api.anthropic.com/v1/models?limit=100")
        .to_return(status: 200, body: api_response, headers: { "Content-Type" => "application/json" })
    end

    it "filters out non-Claude models" do
      models = service.chat_models

      model_ids = models.map { |m| m[:id] }
      expect(model_ids).not_to include("some-other-model")
    end

    it "filters out instant models" do
      models = service.chat_models

      model_ids = models.map { |m| m[:id] }
      expect(model_ids).not_to include("claude-instant-1.2")
    end

    it "includes regular Claude models" do
      models = service.chat_models

      model_ids = models.map { |m| m[:id] }
      expect(model_ids).to include("claude-sonnet-4-20250514")
      expect(model_ids).to include("claude-3-5-haiku-20241022")
    end
  end

  describe "FALLBACK_MODELS" do
    it "includes common Claude models" do
      model_ids = AnthropicModelsService::FALLBACK_MODELS.map { |m| m[:id] }

      expect(model_ids).to include("claude-sonnet-4-20250514")
      expect(model_ids).to include("claude-3-5-sonnet-20241022")
      expect(model_ids).to include("claude-3-5-haiku-20241022")
      expect(model_ids).to include("claude-3-opus-20240229")
    end

    it "includes display names" do
      AnthropicModelsService::FALLBACK_MODELS.each do |model|
        expect(model[:display_name]).to be_present
      end
    end
  end
end

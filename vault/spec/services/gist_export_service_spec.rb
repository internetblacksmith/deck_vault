# frozen_string_literal: true

require "rails_helper"

RSpec.describe GistExportService do
  let(:service) { described_class.new }

  before do
    # Clear any existing settings
    Setting.delete(Setting::GITHUB_TOKEN)
    Setting.delete(Setting::SHOWCASE_GIST_ID)
    # Set token via Setting (which also checks ENV as fallback)
    Setting.github_token = "test-github-token"
  end

  after do
    Setting.delete(Setting::GITHUB_TOKEN)
    Setting.delete(Setting::SHOWCASE_GIST_ID)
  end

  describe "#export" do
    context "without GITHUB_TOKEN configured" do
      before do
        Setting.delete(Setting::GITHUB_TOKEN)
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("GITHUB_TOKEN").and_return(nil)
      end

      it "returns error" do
        result = service.export
        expect(result[:success]).to be false
        expect(result[:error]).to eq("GITHUB_TOKEN not configured")
      end
    end

    context "with valid configuration" do
      let!(:card_set) { create(:card_set, :completed, code: "test", name: "Test Set") }
      let!(:card) { create(:card, card_set: card_set, name: "Test Card") }
      let!(:collection_card) { create(:collection_card, card: card, quantity: 2, foil_quantity: 1) }

      let(:mock_response) do
        {
          "id" => "abc123gist",
          "html_url" => "https://gist.github.com/user/abc123gist",
          "files" => {
            "deck_vault_collection.json" => {
              "raw_url" => "https://gist.githubusercontent.com/raw/abc123gist/mtg_collection.json"
            }
          }
        }
      end

      before do
        stub_request(:post, "https://api.github.com/gists")
          .with(
            headers: {
              "Authorization" => "Bearer test-github-token",
              "Accept" => "application/vnd.github+json",
              "User-Agent" => "DeckVault/1.0"
            }
          )
          .to_return(status: 200, body: mock_response.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "creates a new gist when SHOWCASE_GIST_ID is not set" do
        result = service.export

        expect(result[:success]).to be true
        expect(result[:gist_id]).to eq("abc123gist")
        expect(result[:gist_url]).to eq("https://gist.github.com/user/abc123gist")
        expect(result[:message]).to include("successfully")
      end

      it "saves the gist_id to settings after creating" do
        service.export
        expect(Setting.showcase_gist_id).to eq("abc123gist")
      end

      it "includes owned cards in the export" do
        result = service.export
        expect(result[:success]).to be true

        # Verify the request was made with correct data
        expect(WebMock).to have_requested(:post, "https://api.github.com/gists")
          .with { |req|
            body = JSON.parse(req.body)
            content = JSON.parse(body["files"]["deck_vault_collection.json"]["content"])

            content["cards"].length == 1 &&
              content["cards"][0]["name"] == "Test Card" &&
              content["cards"][0]["quantity"] == 2 &&
              content["cards"][0]["foil_quantity"] == 1
          }
      end
    end

    context "with existing SHOWCASE_GIST_ID" do
      let(:gist_id) { "existing123" }
      let!(:card_set) { create(:card_set, :completed) }

      before do
        Setting.showcase_gist_id = gist_id

        stub_request(:patch, "https://api.github.com/gists/#{gist_id}")
          .to_return(
            status: 200,
            body: {
              "id" => gist_id,
              "html_url" => "https://gist.github.com/user/#{gist_id}",
              "files" => {
                "deck_vault_collection.json" => {
                  "raw_url" => "https://gist.githubusercontent.com/raw/#{gist_id}/mtg_collection.json"
                }
              }
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "updates the existing gist" do
        result = service.export

        expect(result[:success]).to be true
        expect(result[:gist_id]).to eq(gist_id)
        expect(result[:message]).to eq("Collection published successfully!")
        expect(WebMock).to have_requested(:patch, "https://api.github.com/gists/#{gist_id}")
      end
    end

    context "with GitHub API error" do
      let!(:card_set) { create(:card_set, :completed) }

      before do
        stub_request(:post, "https://api.github.com/gists")
          .to_return(
            status: 401,
            body: { "message" => "Bad credentials" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns error with API message" do
        result = service.export

        expect(result[:success]).to be false
        expect(result[:error]).to include("GitHub API error")
        expect(result[:error]).to include("Bad credentials")
      end
    end
  end

  describe "#raw_url" do
    context "without SHOWCASE_GIST_ID" do
      it "returns nil" do
        expect(service.raw_url).to be_nil
      end
    end

    context "with SHOWCASE_GIST_ID" do
      before do
        Setting.showcase_gist_id = "test123"
      end

      it "returns the raw URL" do
        expect(service.raw_url).to eq("https://gist.githubusercontent.com/raw/test123/deck_vault_collection.json")
      end
    end
  end

  describe "data format" do
    let!(:card_set) do
      create(:card_set, :completed,
        code: "fdn",
        name: "Foundations",
        released_at: Date.new(2024, 11, 15)
      )
    end
    let!(:card1) { create(:card, card_set: card_set, name: "Card A", collector_number: "1", rarity: "rare") }
    let!(:card2) { create(:card, card_set: card_set, name: "Card B", collector_number: "2", rarity: "common") }
    let!(:card3) { create(:card, card_set: card_set, name: "Card C", collector_number: "3", rarity: "uncommon") }
    let!(:collection1) { create(:collection_card, card: card1, quantity: 1, foil_quantity: 2) }
    let!(:collection2) { create(:collection_card, card: card2, quantity: 3, foil_quantity: 0) }
    # card3 is not owned

    before do
      stub_request(:post, "https://api.github.com/gists")
        .to_return(
          status: 200,
          body: {
            "id" => "test",
            "html_url" => "https://gist.github.com/user/test",
            "files" => { "deck_vault_collection.json" => { "raw_url" => "https://example.com/raw" } }
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "exports data in Showcase-compatible format" do
      service.export

      expect(WebMock).to have_requested(:post, "https://api.github.com/gists")
        .with { |req|
          body = JSON.parse(req.body)
          content = JSON.parse(body["files"]["deck_vault_collection.json"]["content"])

          # Check top-level structure
          content["version"] == 2 &&
            content["export_type"] == "showcase" &&
            content.key?("exported_at") &&
            content.key?("stats") &&
            content.key?("sets") &&
            content.key?("cards")
        }
    end

    it "includes correct stats" do
      service.export

      expect(WebMock).to have_requested(:post, "https://api.github.com/gists")
        .with { |req|
          body = JSON.parse(req.body)
          content = JSON.parse(body["files"]["deck_vault_collection.json"]["content"])
          stats = content["stats"]

          stats["total_unique"] == 2 &&          # 2 owned cards
            stats["total_cards"] == 6 &&          # 1+2+3 = 6 total
            stats["total_foils"] == 2 &&          # 2 foil copies
            stats["sets_collected"] == 1
        }
    end

    it "includes set data with completion percentage" do
      service.export

      expect(WebMock).to have_requested(:post, "https://api.github.com/gists")
        .with { |req|
          body = JSON.parse(req.body)
          content = JSON.parse(body["files"]["deck_vault_collection.json"]["content"])
          set_data = content["sets"].first

          set_data["code"] == "fdn" &&
            set_data["name"] == "Foundations" &&
            set_data["card_count"] == 3 &&
            set_data["owned_count"] == 2
        }
    end

    it "only includes owned cards in cards array" do
      service.export

      expect(WebMock).to have_requested(:post, "https://api.github.com/gists")
        .with { |req|
          body = JSON.parse(req.body)
          content = JSON.parse(body["files"]["deck_vault_collection.json"]["content"])

          content["cards"].length == 2 &&
            content["cards"].map { |c| c["name"] }.sort == [ "Card A", "Card B" ]
        }
    end

    it "includes set_code and set_name in each card" do
      service.export

      expect(WebMock).to have_requested(:post, "https://api.github.com/gists")
        .with { |req|
          body = JSON.parse(req.body)
          content = JSON.parse(body["files"]["deck_vault_collection.json"]["content"])

          content["cards"].all? { |c|
            c["set_code"] == "fdn" && c["set_name"] == "Foundations"
          }
        }
    end
  end
end

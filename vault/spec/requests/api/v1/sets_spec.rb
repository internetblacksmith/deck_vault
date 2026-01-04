# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Sets" do
  describe "GET /api/v1/sets" do
    context "with no sets" do
      it "returns empty array" do
        get "/api/v1/sets"

        expect(response).to have_http_status(:ok)
        json = response.parsed_body

        expect(json["sets"]).to eq([])
      end
    end

    context "with completed sets" do
      let!(:set1) { create(:card_set, :completed, name: "Zendikar", code: "zen") }
      let!(:set2) { create(:card_set, :completed, name: "Alpha", code: "lea") }
      let!(:pending_set) { create(:card_set, download_status: :pending, name: "Pending", code: "pnd") }

      it "returns only completed sets ordered by name" do
        get "/api/v1/sets"

        expect(response).to have_http_status(:ok)
        json = response.parsed_body

        expect(json["sets"].length).to eq(2)
        expect(json["sets"][0]["name"]).to eq("Alpha")
        expect(json["sets"][1]["name"]).to eq("Zendikar")
      end

      it "includes set details" do
        create(:card, card_set: set1)
        create(:card, card_set: set1)

        get "/api/v1/sets"

        json = response.parsed_body
        zen_set = json["sets"].find { |s| s["code"] == "zen" }

        expect(zen_set["code"]).to eq("zen")
        expect(zen_set["name"]).to eq("Zendikar")
        expect(zen_set["card_count"]).to eq(2)
        expect(zen_set["download_status"]).to eq("completed")
      end
    end
  end

  describe "GET /api/v1/sets/:id" do
    let!(:card_set) { create(:card_set, :completed, code: "zen", name: "Zendikar") }
    let!(:card1) { create(:card, card_set: card_set, name: "Lightning Bolt", collector_number: "1") }
    let!(:card2) { create(:card, card_set: card_set, name: "Counterspell", collector_number: "2") }
    let!(:collection) { create(:collection_card, card: card1, quantity: 4) }

    it "returns set with cards" do
      get "/api/v1/sets/zen"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body

      expect(json["set"]["code"]).to eq("zen")
      expect(json["set"]["name"]).to eq("Zendikar")
      expect(json["cards"].length).to eq(2)
    end

    it "returns cards ordered by collector number" do
      get "/api/v1/sets/zen"

      json = response.parsed_body
      expect(json["cards"][0]["collector_number"]).to eq("1")
      expect(json["cards"][1]["collector_number"]).to eq("2")
    end

    it "includes card ownership info" do
      get "/api/v1/sets/zen"

      json = response.parsed_body
      bolt = json["cards"].find { |c| c["name"] == "Lightning Bolt" }
      counterspell = json["cards"].find { |c| c["name"] == "Counterspell" }

      expect(bolt["quantity"]).to eq(4)
      expect(bolt["owned"]).to be true
      expect(counterspell["quantity"]).to eq(0)
      expect(counterspell["owned"]).to be false
    end

    it "handles case-insensitive set codes" do
      get "/api/v1/sets/ZEN"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["set"]["code"]).to eq("zen")
    end

    it "returns 404 for unknown set" do
      get "/api/v1/sets/unknown"

      expect(response).to have_http_status(:not_found)
      json = response.parsed_body
      expect(json["error"]).to eq("Not found")
    end
  end

  describe "POST /api/v1/sets/download" do
    context "with missing set_code" do
      it "returns error" do
        post "/api/v1/sets/download"

        expect(response).to have_http_status(422)
        json = response.parsed_body
        expect(json["error"]).to eq("set_code is required")
      end
    end

    context "when set already exists" do
      let!(:existing_set) { create(:card_set, :completed, code: "zen", name: "Zendikar") }

      it "returns existing set" do
        post "/api/v1/sets/download", params: { set_code: "zen" }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["message"]).to eq("Set already downloaded")
        expect(json["set"]["code"]).to eq("zen")
      end
    end

    context "when downloading new set" do
      before do
        allow(ScryfallService).to receive(:download_set).and_return(
          create(:card_set, code: "neo", name: "Kamigawa: Neon Dynasty", download_status: :downloading)
        )
      end

      it "starts download and returns set" do
        post "/api/v1/sets/download", params: { set_code: "neo" }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json["message"]).to eq("Set download started")
        expect(json["set"]["code"]).to eq("neo")
      end

      it "handles case-insensitive set codes" do
        post "/api/v1/sets/download", params: { set_code: "NEO" }

        expect(ScryfallService).to have_received(:download_set).with("neo", include_children: false)
      end
    end

    context "when Scryfall fails" do
      before do
        allow(ScryfallService).to receive(:download_set).and_return(nil)
      end

      it "returns error" do
        post "/api/v1/sets/download", params: { set_code: "invalid" }

        expect(response).to have_http_status(422)
        json = response.parsed_body
        expect(json["error"]).to eq("Failed to download set from Scryfall")
      end
    end
  end
end

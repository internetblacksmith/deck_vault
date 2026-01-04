# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Cards" do
  let!(:card_set) { create(:card_set, :completed, code: "zen", name: "Zendikar") }

  describe "GET /api/v1/cards" do
    let!(:card1) { create(:card, card_set: card_set, name: "Lightning Bolt", rarity: "common") }
    let!(:card2) { create(:card, card_set: card_set, name: "Counterspell", rarity: "uncommon") }
    let!(:card3) { create(:card, card_set: card_set, name: "Black Lotus", rarity: "rare") }
    let!(:collection1) { create(:collection_card, card: card1, quantity: 4) }

    it "returns all cards" do
      get "/api/v1/cards"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body

      expect(json["count"]).to eq(3)
      expect(json["cards"].length).to eq(3)
    end

    context "with search query" do
      it "filters by name" do
        get "/api/v1/cards", params: { q: "bolt" }

        json = response.parsed_body
        expect(json["count"]).to eq(1)
        expect(json["cards"][0]["name"]).to eq("Lightning Bolt")
      end

      it "is case-insensitive" do
        get "/api/v1/cards", params: { q: "BOLT" }

        json = response.parsed_body
        expect(json["count"]).to eq(1)
      end

      it "matches partial names" do
        get "/api/v1/cards", params: { q: "ounter" }

        json = response.parsed_body
        expect(json["count"]).to eq(1)
        expect(json["cards"][0]["name"]).to eq("Counterspell")
      end
    end

    context "with set filter" do
      let!(:other_set) { create(:card_set, :completed, code: "lea", name: "Alpha") }
      let!(:alpha_card) { create(:card, card_set: other_set, name: "Mox Ruby") }

      it "filters by set code" do
        get "/api/v1/cards", params: { set: "zen" }

        json = response.parsed_body
        expect(json["count"]).to eq(3)
        expect(json["cards"].map { |c| c["set_code"] }).to all(eq("zen"))
      end

      it "handles case-insensitive set codes" do
        get "/api/v1/cards", params: { set: "ZEN" }

        json = response.parsed_body
        expect(json["count"]).to eq(3)
      end
    end

    context "with rarity filter" do
      it "filters by rarity" do
        get "/api/v1/cards", params: { rarity: "common" }

        json = response.parsed_body
        expect(json["count"]).to eq(1)
        expect(json["cards"][0]["rarity"]).to eq("common")
      end
    end

    context "with owned filter" do
      it "returns only owned cards when owned=true" do
        get "/api/v1/cards", params: { owned: "true" }

        json = response.parsed_body
        expect(json["count"]).to eq(1)
        expect(json["cards"][0]["name"]).to eq("Lightning Bolt")
      end
    end

    context "with missing filter" do
      it "returns only missing cards when missing=true" do
        get "/api/v1/cards", params: { missing: "true" }

        json = response.parsed_body
        expect(json["count"]).to eq(2)
        names = json["cards"].map { |c| c["name"] }
        expect(names).to contain_exactly("Counterspell", "Black Lotus")
      end
    end

    context "with combined filters" do
      it "combines set and rarity filters" do
        get "/api/v1/cards", params: { set: "zen", rarity: "rare" }

        json = response.parsed_body
        expect(json["count"]).to eq(1)
        expect(json["cards"][0]["name"]).to eq("Black Lotus")
      end

      it "combines search and owned filters" do
        get "/api/v1/cards", params: { q: "bolt", owned: "true" }

        json = response.parsed_body
        expect(json["count"]).to eq(1)
        expect(json["cards"][0]["name"]).to eq("Lightning Bolt")
      end
    end

    context "with limit parameter" do
      before do
        10.times { |i| create(:card, card_set: card_set, name: "Card #{i}") }
      end

      it "limits results" do
        get "/api/v1/cards", params: { limit: 5 }

        json = response.parsed_body
        expect(json["cards"].length).to eq(5)
      end

      it "defaults to 100" do
        get "/api/v1/cards"

        json = response.parsed_body
        expect(json["cards"].length).to eq(13) # 3 original + 10 new
      end

      it "caps at 500" do
        get "/api/v1/cards", params: { limit: 1000 }

        json = response.parsed_body
        # Would be capped at 500, but we only have 13 cards
        expect(json["cards"].length).to eq(13)
      end
    end
  end

  describe "GET /api/v1/cards/:id" do
    let!(:card) do
      create(:card,
        card_set: card_set,
        name: "Lightning Bolt",
        oracle_text: "Lightning Bolt deals 3 damage to any target.",
        image_uris: { "normal" => "https://example.com/bolt.jpg" }.to_json
      )
    end
    let!(:collection) { create(:collection_card, card: card, quantity: 4, foil_quantity: 2) }

    it "returns card details" do
      get "/api/v1/cards/#{card.id}"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body["card"]

      expect(json["id"]).to eq(card.id)
      expect(json["name"]).to eq("Lightning Bolt")
      expect(json["set_code"]).to eq("zen")
      expect(json["set_name"]).to eq("Zendikar")
      expect(json["oracle_text"]).to eq("Lightning Bolt deals 3 damage to any target.")
      expect(json["image_url"]).to eq("https://example.com/bolt.jpg")
      expect(json["quantity"]).to eq(4)
      expect(json["foil_quantity"]).to eq(2)
      expect(json["owned"]).to be true
    end

    it "returns 404 for unknown card" do
      get "/api/v1/cards/nonexistent-uuid"

      expect(response).to have_http_status(:not_found)
      json = response.parsed_body
      expect(json["error"]).to eq("Not found")
    end
  end

  describe "PATCH /api/v1/cards/:id" do
    let!(:card) { create(:card, card_set: card_set, name: "Lightning Bolt") }

    context "without existing collection record" do
      it "creates collection record with quantity" do
        patch "/api/v1/cards/#{card.id}", params: { quantity: 4 }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body

        expect(json["message"]).to eq("Card updated")
        expect(json["card"]["quantity"]).to eq(4)
        expect(CollectionCard.find_by(card: card).quantity).to eq(4)
      end

      it "creates collection record with foil quantity" do
        patch "/api/v1/cards/#{card.id}", params: { foil_quantity: 2 }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body

        expect(json["card"]["foil_quantity"]).to eq(2)
      end
    end

    context "with existing collection record" do
      let!(:collection) { create(:collection_card, card: card, quantity: 2, foil_quantity: 1) }

      it "updates quantity" do
        patch "/api/v1/cards/#{card.id}", params: { quantity: 8 }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body

        expect(json["card"]["quantity"]).to eq(8)
        expect(json["card"]["foil_quantity"]).to eq(1) # unchanged
      end

      it "updates foil quantity" do
        patch "/api/v1/cards/#{card.id}", params: { foil_quantity: 5 }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body

        expect(json["card"]["quantity"]).to eq(2) # unchanged
        expect(json["card"]["foil_quantity"]).to eq(5)
      end

      it "updates both quantities" do
        patch "/api/v1/cards/#{card.id}", params: { quantity: 10, foil_quantity: 3 }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body

        expect(json["card"]["quantity"]).to eq(10)
        expect(json["card"]["foil_quantity"]).to eq(3)
      end

      it "can set quantity to zero" do
        patch "/api/v1/cards/#{card.id}", params: { quantity: 0 }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body

        expect(json["card"]["quantity"]).to eq(0)
        expect(json["card"]["owned"]).to be true # still has foils
      end
    end

    it "returns 404 for unknown card" do
      patch "/api/v1/cards/nonexistent-uuid", params: { quantity: 4 }

      expect(response).to have_http_status(:not_found)
    end
  end
end

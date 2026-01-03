# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Stats" do
  describe "GET /api/v1/stats" do
    context "with no data" do
      it "returns empty stats" do
        get "/api/v1/stats"

        expect(response).to have_http_status(:ok)
        json = response.parsed_body

        expect(json["sets_downloaded"]).to eq(0)
        expect(json["total_cards"]).to eq(0)
        expect(json["unique_cards_owned"]).to eq(0)
        expect(json["total_cards_owned"]).to eq(0)
        expect(json["sets"]).to eq([])
      end
    end

    context "with collection data" do
      let!(:card_set) { create(:card_set, :completed) }
      let!(:card1) { create(:card, card_set: card_set, name: "Lightning Bolt") }
      let!(:card2) { create(:card, card_set: card_set, name: "Counterspell") }
      let!(:card3) { create(:card, card_set: card_set, name: "Giant Growth") }
      let!(:collection1) { create(:collection_card, card: card1, quantity: 4, foil_quantity: 1) }
      let!(:collection2) { create(:collection_card, card: card2, quantity: 2, foil_quantity: 0) }

      it "returns collection statistics" do
        get "/api/v1/stats"

        expect(response).to have_http_status(:ok)
        json = response.parsed_body

        expect(json["sets_downloaded"]).to eq(1)
        expect(json["total_cards"]).to eq(3)
        expect(json["unique_cards_owned"]).to eq(2)
        expect(json["total_cards_owned"]).to eq(7) # 4 + 1 + 2
        expect(json["total_regular"]).to eq(6)     # 4 + 2
        expect(json["total_foils"]).to eq(1)
      end

      it "includes per-set breakdown" do
        get "/api/v1/stats"

        json = response.parsed_body
        set_stats = json["sets"].first

        expect(set_stats["code"]).to eq(card_set.code)
        expect(set_stats["name"]).to eq(card_set.name)
        expect(set_stats["cards_in_set"]).to eq(3)
        expect(set_stats["cards_owned"]).to eq(2)
        expect(set_stats["completion_percentage"]).to eq(66.7)
      end
    end

    context "with multiple sets" do
      let!(:set1) { create(:card_set, :completed, name: "Alpha", code: "lea") }
      let!(:set2) { create(:card_set, :completed, name: "Beta", code: "leb") }
      let!(:set3) { create(:card_set, download_status: :pending, name: "Pending Set", code: "pnd") }
      let!(:card1) { create(:card, card_set: set1) }
      let!(:card2) { create(:card, card_set: set2) }
      let!(:card3) { create(:card, card_set: set3) }

      it "only counts completed sets" do
        get "/api/v1/stats"

        json = response.parsed_body

        expect(json["sets_downloaded"]).to eq(2)
        expect(json["sets"].length).to eq(2)
        expect(json["sets"].map { |s| s["code"] }).to contain_exactly("lea", "leb")
      end
    end
  end
end

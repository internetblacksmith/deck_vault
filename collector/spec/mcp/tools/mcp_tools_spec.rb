# frozen_string_literal: true

require "rails_helper"

# Load MCP tools
Dir[Rails.root.join("app/mcp/tools/*.rb")].each { |f| require f }

RSpec.describe "MCP Tools" do
  let!(:card_set) { create(:card_set, :completed, name: "Test Set", code: "tst") }
  let!(:card1) { create(:card, card_set: card_set, name: "Lightning Bolt", rarity: "common", collector_number: "1") }
  let!(:card2) { create(:card, card_set: card_set, name: "Counterspell", rarity: "uncommon", collector_number: "2") }
  let!(:card3) { create(:card, card_set: card_set, name: "Black Lotus", rarity: "rare", collector_number: "3") }
  let!(:collection1) { create(:collection_card, card: card1, quantity: 4, foil_quantity: 1) }

  describe Mcp::Tools::GetCollectionStatsTool do
    it "has correct tool name" do
      expect(described_class.tool_name).to eq("get_collection_stats")
    end

    it "returns collection statistics" do
      response = described_class.call(server_context: {})

      expect(response).to be_a(MCP::Tool::Response)
      json = JSON.parse(response.content.first[:text])

      expect(json["sets_downloaded"]).to eq(1)
      expect(json["total_cards_in_sets"]).to eq(3)
      expect(json["unique_cards_owned"]).to eq(1)
      expect(json["total_cards_owned"]).to eq(5) # 4 regular + 1 foil
    end
  end

  describe Mcp::Tools::ListSetsTool do
    it "has correct tool name" do
      expect(described_class.tool_name).to eq("list_sets")
    end

    it "returns completed sets" do
      create(:card_set, download_status: :pending, code: "pnd")

      response = described_class.call(server_context: {})

      json = JSON.parse(response.content.first[:text])

      expect(json.length).to eq(1)
      expect(json.first["code"]).to eq("tst")
      expect(json.first["name"]).to eq("Test Set")
      expect(json.first["cards_in_set"]).to eq(3)
      expect(json.first["cards_owned"]).to eq(1)
    end
  end

  describe Mcp::Tools::GetSetDetailsTool do
    it "has correct tool name" do
      expect(described_class.tool_name).to eq("get_set_details")
    end

    it "has set_code in input schema properties" do
      expect(described_class.input_schema).to be_present
    end

    it "returns cards for a set" do
      response = described_class.call(set_code: "tst", server_context: {})

      json = JSON.parse(response.content.first[:text])

      expect(json["set_code"]).to eq("tst")
      expect(json["set_name"]).to eq("Test Set")
      expect(json["cards"].length).to eq(3)
    end

    it "returns cards ordered by collector number" do
      response = described_class.call(set_code: "tst", server_context: {})

      json = JSON.parse(response.content.first[:text])
      numbers = json["cards"].map { |c| c["number"] }

      expect(numbers).to eq(%w[1 2 3])
    end

    it "returns error for unknown set" do
      response = described_class.call(set_code: "unknown", server_context: {})

      json = JSON.parse(response.content.first[:text])

      expect(json["error"]).to include("not found")
    end
  end

  describe Mcp::Tools::SearchCardsTool do
    it "has correct tool name" do
      expect(described_class.tool_name).to eq("search_cards")
    end

    it "searches cards by name" do
      response = described_class.call(query: "bolt", server_context: {})

      json = JSON.parse(response.content.first[:text])

      expect(json.length).to eq(1)
      expect(json.first["name"]).to eq("Lightning Bolt")
    end

    it "filters by rarity" do
      response = described_class.call(rarity: "rare", server_context: {})

      json = JSON.parse(response.content.first[:text])

      expect(json.length).to eq(1)
      expect(json.first["name"]).to eq("Black Lotus")
    end

    it "filters by set code" do
      other_set = create(:card_set, :completed, code: "oth")
      create(:card, card_set: other_set, name: "Other Bolt")

      response = described_class.call(query: "bolt", set_code: "tst", server_context: {})

      json = JSON.parse(response.content.first[:text])

      expect(json.length).to eq(1)
      expect(json.first["set_code"]).to eq("tst")
    end

    it "filters owned only" do
      response = described_class.call(owned_only: true, server_context: {})

      json = JSON.parse(response.content.first[:text])

      expect(json.length).to eq(1)
      expect(json.first["name"]).to eq("Lightning Bolt")
    end
  end

  describe Mcp::Tools::GetOwnedCardsTool do
    it "has correct tool name" do
      expect(described_class.tool_name).to eq("get_owned_cards")
    end

    it "returns only owned cards" do
      response = described_class.call(server_context: {})

      json = JSON.parse(response.content.first[:text])

      expect(json.length).to eq(1)
      expect(json.first["name"]).to eq("Lightning Bolt")
      expect(json.first["quantity"]).to eq(4)
      expect(json.first["foil_quantity"]).to eq(1)
    end

    it "filters by set code" do
      other_set = create(:card_set, :completed, code: "oth")
      other_card = create(:card, card_set: other_set, name: "Other Card")
      create(:collection_card, card: other_card, quantity: 1)

      response = described_class.call(set_code: "tst", server_context: {})

      json = JSON.parse(response.content.first[:text])

      expect(json.length).to eq(1)
      expect(json.first["set_code"]).to eq("tst")
    end
  end

  describe Mcp::Tools::GetMissingCardsTool do
    it "has correct tool name" do
      expect(described_class.tool_name).to eq("get_missing_cards")
    end

    it "returns only missing cards" do
      response = described_class.call(server_context: {})

      json = JSON.parse(response.content.first[:text])

      expect(json.length).to eq(2)
      names = json.map { |c| c["name"] }
      expect(names).to contain_exactly("Counterspell", "Black Lotus")
    end

    it "filters by set code" do
      response = described_class.call(set_code: "tst", server_context: {})

      json = JSON.parse(response.content.first[:text])

      expect(json.all? { |c| c["set_code"] == "tst" }).to be true
    end
  end

  describe Mcp::Tools::UpdateCardQuantityTool do
    it "has correct tool name" do
      expect(described_class.tool_name).to eq("update_card_quantity")
    end

    it "has card_id in input schema properties" do
      expect(described_class.input_schema).to be_present
    end

    it "updates regular quantity" do
      response = described_class.call(card_id: card2.id, quantity: 3, server_context: {})

      json = JSON.parse(response.content.first[:text])

      expect(json["success"]).to be true
      expect(json["quantity"]).to eq(3)
      expect(CollectionCard.find_by(card: card2).quantity).to eq(3)
    end

    it "updates foil quantity" do
      response = described_class.call(card_id: card2.id, foil_quantity: 2, server_context: {})

      json = JSON.parse(response.content.first[:text])

      expect(json["success"]).to be true
      expect(json["foil_quantity"]).to eq(2)
    end

    it "returns error for unknown card" do
      response = described_class.call(card_id: "nonexistent", server_context: {})

      json = JSON.parse(response.content.first[:text])

      expect(json["error"]).to include("not found")
    end
  end
end

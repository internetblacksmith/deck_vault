# frozen_string_literal: true

require "rails_helper"

RSpec.describe ChatService do
  let(:mock_client) { instance_double(Anthropic::Client) }
  let(:mock_messages) { instance_double("Messages") }
  let(:service) { described_class.new }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ANTHROPIC_API_KEY").and_return("test-key")
    allow(ENV).to receive(:fetch).with("ANTHROPIC_API_KEY", nil).and_return("test-key")
    allow(Anthropic::Client).to receive(:new).and_return(mock_client)
    allow(mock_client).to receive(:messages).and_return(mock_messages)
  end

  describe "#initialize" do
    context "without ANTHROPIC_API_KEY" do
      before do
        allow(Anthropic::Client).to receive(:new).and_call_original
        allow(ENV).to receive(:fetch).with("ANTHROPIC_API_KEY", nil).and_return(nil)
      end

      it "raises configuration error" do
        expect { described_class.new }.to raise_error(Anthropic::ConfigurationError)
      end
    end
  end

  describe "#chat" do
    context "without API key in environment" do
      it "raises an error when calling chat" do
        allow(ENV).to receive(:[]).with("ANTHROPIC_API_KEY").and_return(nil)

        expect { service.chat([ { role: "user", content: "Hello" } ]) }
          .to raise_error("Anthropic API key not configured. Please add it in Settings.")
      end
    end

    context "with simple text response" do
      let(:mock_response) do
        double(
          "Response",
          stop_reason: "end_turn",
          content: [
            double("TextContent", type: "text", text: "Hello! I can help you with your collection.")
          ]
        )
      end

      before do
        allow(mock_messages).to receive(:create).and_return(mock_response)
      end

      it "returns the response text" do
        result = service.chat([ { role: "user", content: "Hello" } ])

        expect(result[:response]).to eq("Hello! I can help you with your collection.")
      end

      it "includes updated message history" do
        result = service.chat([ { role: "user", content: "Hello" } ])

        expect(result[:messages]).to be_an(Array)
        expect(result[:messages].last[:role]).to eq("assistant")
      end

      it "calls Anthropic with correct parameters" do
        service.chat([ { role: "user", content: "Test message" } ])

        expect(mock_messages).to have_received(:create).with(hash_including(
          model: "claude-sonnet-4-20250514",
          max_tokens: 4096
        ))
      end
    end

    context "with tool use response" do
      let(:tool_use_response) do
        double(
          "Response",
          stop_reason: "tool_use",
          content: [
            double("ToolUse",
              type: "tool_use",
              id: "tool_123",
              name: "get_collection_stats",
              input: {}
            )
          ]
        )
      end

      let(:final_response) do
        double(
          "Response",
          stop_reason: "end_turn",
          content: [
            double("TextContent", type: "text", text: "You have 5 sets with 100 cards.")
          ]
        )
      end

      before do
        # First call returns tool use, second call returns final response
        call_count = 0
        allow(mock_messages).to receive(:create) do
          call_count += 1
          call_count == 1 ? tool_use_response : final_response
        end
      end

      it "executes tool and returns final response" do
        # Create some test data
        create(:card_set, :completed)

        result = service.chat([ { role: "user", content: "What are my stats?" } ])

        expect(result[:response]).to eq("You have 5 sets with 100 cards.")
      end

      it "makes multiple API calls for tool use" do
        create(:card_set, :completed)

        service.chat([ { role: "user", content: "What are my stats?" } ])

        expect(mock_messages).to have_received(:create).twice
      end
    end
  end

  describe "tool execution" do
    let!(:card_set) { create(:card_set, :completed, name: "Test Set", code: "tst") }
    let!(:card1) { create(:card, card_set: card_set, name: "Lightning Bolt") }
    let!(:card2) { create(:card, card_set: card_set, name: "Counterspell") }
    let!(:collection) { create(:collection_card, card: card1, quantity: 4, foil_quantity: 1) }

    describe "#get_collection_stats" do
      it "returns collection statistics" do
        stats = service.send(:get_collection_stats)

        expect(stats[:sets_downloaded]).to eq(1)
        expect(stats[:total_cards_in_sets]).to eq(2)
        expect(stats[:unique_cards_owned]).to eq(1)
        expect(stats[:total_cards_owned]).to eq(5) # 4 regular + 1 foil
      end
    end

    describe "#list_sets" do
      it "returns completed sets" do
        sets = service.send(:list_sets)

        expect(sets.length).to eq(1)
        expect(sets.first[:code]).to eq("tst")
        expect(sets.first[:name]).to eq("Test Set")
        expect(sets.first[:cards_in_set]).to eq(2)
        expect(sets.first[:cards_owned]).to eq(1)
      end
    end

    describe "#get_set_cards" do
      it "returns cards for a set" do
        cards = service.send(:get_set_cards, "tst")

        expect(cards.length).to eq(2)
        bolt = cards.find { |c| c[:name] == "Lightning Bolt" }
        expect(bolt[:quantity]).to eq(4)
        expect(bolt[:foil_quantity]).to eq(1)
      end

      it "returns error for unknown set" do
        result = service.send(:get_set_cards, "unknown")

        expect(result[:error]).to include("not found")
      end
    end

    describe "#search_cards" do
      it "finds cards by name" do
        cards = service.send(:search_cards, "bolt")

        expect(cards.length).to eq(1)
        expect(cards.first[:name]).to eq("Lightning Bolt")
      end

      it "filters by set" do
        other_set = create(:card_set, :completed, code: "oth")
        create(:card, card_set: other_set, name: "Bolt of Lightning")

        cards = service.send(:search_cards, "bolt", "tst")

        expect(cards.length).to eq(1)
        expect(cards.first[:set_code]).to eq("tst")
      end
    end

    describe "#get_owned_cards" do
      it "returns only owned cards" do
        cards = service.send(:get_owned_cards, nil)

        expect(cards.length).to eq(1)
        expect(cards.first[:name]).to eq("Lightning Bolt")
      end
    end

    describe "#get_missing_cards" do
      it "returns only missing cards" do
        cards = service.send(:get_missing_cards, nil)

        expect(cards.length).to eq(1)
        expect(cards.first[:name]).to eq("Counterspell")
      end
    end

    describe "#update_card_quantity" do
      it "updates card quantity" do
        result = service.send(:update_card_quantity, card2.id, 3, nil)

        expect(result[:success]).to be true
        expect(result[:quantity]).to eq(3)
        expect(CollectionCard.find_by(card: card2).quantity).to eq(3)
      end

      it "updates foil quantity" do
        result = service.send(:update_card_quantity, card1.id, nil, 5)

        expect(result[:success]).to be true
        expect(result[:foil_quantity]).to eq(5)
        expect(CollectionCard.find_by(card: card1).foil_quantity).to eq(5)
      end

      it "returns error for unknown card" do
        result = service.send(:update_card_quantity, "nonexistent", 1, nil)

        expect(result[:error]).to include("not found")
      end
    end
  end

  describe "TOOLS constant" do
    it "defines all required tools" do
      tool_names = ChatService::TOOLS.map { |t| t[:name] }

      expect(tool_names).to include(
        "get_collection_stats",
        "list_sets",
        "get_set_cards",
        "search_cards",
        "get_owned_cards",
        "get_missing_cards",
        "update_card_quantity"
      )
    end

    it "includes input schemas for all tools" do
      ChatService::TOOLS.each do |tool|
        expect(tool[:input_schema]).to be_a(Hash)
        expect(tool[:input_schema][:type]).to eq("object")
      end
    end
  end
end

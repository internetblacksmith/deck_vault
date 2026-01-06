# frozen_string_literal: true

# Service to handle chat with Claude, with access to collection tools
class ChatService
  SYSTEM_PROMPT = <<~PROMPT
    You are a helpful assistant for an MTG (Magic: The Gathering) card collection management app.
    You help users manage their card collection, find cards, track what they own, and provide information about sets and cards.

    You have access to the following tools to query and modify the user's collection:
    - get_collection_stats: Get overall collection statistics
    - list_sets: List all downloaded sets
    - get_set_cards: Get all cards in a specific set
    - search_cards: Search for cards by name
    - get_owned_cards: Get cards the user owns
    - get_missing_cards: Get cards the user doesn't own from downloaded sets
    - update_card_quantity: Update how many copies of a card the user owns

    Be concise but helpful. When showing card lists, format them nicely.
    If the user asks about cards they don't have downloaded, suggest they download the set first.
  PROMPT

  TOOLS = [
    {
      name: "get_collection_stats",
      description: "Get statistics about the user's MTG card collection including total cards, sets, and owned cards",
      input_schema: {
        type: "object",
        properties: {},
        required: []
      }
    },
    {
      name: "list_sets",
      description: "List all downloaded MTG sets in the collection",
      input_schema: {
        type: "object",
        properties: {},
        required: []
      }
    },
    {
      name: "get_set_cards",
      description: "Get all cards in a specific set with ownership status",
      input_schema: {
        type: "object",
        properties: {
          set_code: {
            type: "string",
            description: "The set code (e.g., 'tla' for Avatar: The Last Airbender)"
          }
        },
        required: [ "set_code" ]
      }
    },
    {
      name: "search_cards",
      description: "Search for cards by name across all downloaded sets",
      input_schema: {
        type: "object",
        properties: {
          query: {
            type: "string",
            description: "Card name or partial name to search for"
          },
          set_code: {
            type: "string",
            description: "Optional: filter by set code"
          }
        },
        required: [ "query" ]
      }
    },
    {
      name: "get_owned_cards",
      description: "Get all cards the user owns with quantities",
      input_schema: {
        type: "object",
        properties: {
          set_code: {
            type: "string",
            description: "Optional: filter by set code"
          }
        },
        required: []
      }
    },
    {
      name: "get_missing_cards",
      description: "Get cards the user doesn't own from downloaded sets",
      input_schema: {
        type: "object",
        properties: {
          set_code: {
            type: "string",
            description: "Optional: filter by set code"
          }
        },
        required: []
      }
    },
    {
      name: "update_card_quantity",
      description: "Update the quantity of a card in the user's collection",
      input_schema: {
        type: "object",
        properties: {
          card_id: {
            type: "string",
            description: "The Scryfall ID of the card"
          },
          quantity: {
            type: "integer",
            description: "New quantity of regular (non-foil) copies"
          },
          foil_quantity: {
            type: "integer",
            description: "New quantity of foil copies"
          }
        },
        required: [ "card_id" ]
      }
    }
  ].freeze

  def initialize
    @api_key = Setting.anthropic_api_key
    @model = Setting.chat_model
    @client = Anthropic::Client.new(api_key: @api_key)
  end

  def chat(messages)
    raise "Anthropic API key not configured. Please add it in Settings." unless @api_key.present?

    response = @client.messages.create(
      model: @model,
      max_tokens: 4096,
      system: SYSTEM_PROMPT,
      tools: TOOLS,
      messages: messages
    )

    # Handle tool use in a loop until we get a final response
    while response.stop_reason == "tool_use"
      tool_results = process_tool_calls(response)
      messages = messages + [
        { role: "assistant", content: response.content },
        { role: "user", content: tool_results }
      ]

      response = @client.messages.create(
        model: @model,
        max_tokens: 4096,
        system: SYSTEM_PROMPT,
        tools: TOOLS,
        messages: messages
      )
    end

    # Extract text response
    text_content = response.content.find { |c| c.type == "text" }
    {
      response: text_content&.text || "I couldn't generate a response.",
      messages: messages + [ { role: "assistant", content: response.content } ]
    }
  end

  private

  def process_tool_calls(response)
    tool_uses = response.content.select { |c| c.type == "tool_use" }

    tool_uses.map do |tool_use|
      result = execute_tool(tool_use.name, tool_use.input)
      {
        type: "tool_result",
        tool_use_id: tool_use.id,
        content: result.to_json
      }
    end
  end

  def execute_tool(name, input)
    case name
    when "get_collection_stats"
      get_collection_stats
    when "list_sets"
      list_sets
    when "get_set_cards"
      get_set_cards(input["set_code"])
    when "search_cards"
      search_cards(input["query"], input["set_code"])
    when "get_owned_cards"
      get_owned_cards(input["set_code"])
    when "get_missing_cards"
      get_missing_cards(input["set_code"])
    when "update_card_quantity"
      update_card_quantity(input["card_id"], input["quantity"], input["foil_quantity"])
    else
      { error: "Unknown tool: #{name}" }
    end
  rescue StandardError => e
    { error: e.message }
  end

  def get_collection_stats
    sets = CardSet.where(download_status: :completed)
    total_cards = sets.sum { |s| s.cards.count }
    owned_regular = CollectionCard.sum(:quantity).to_i
    owned_foil = CollectionCard.sum(:foil_quantity).to_i

    {
      sets_downloaded: sets.count,
      total_cards_in_sets: total_cards,
      unique_cards_owned: CollectionCard.where("quantity > 0 OR foil_quantity > 0").count,
      total_regular_owned: owned_regular,
      total_foils_owned: owned_foil,
      total_cards_owned: owned_regular + owned_foil
    }
  end

  def list_sets
    CardSet.where(download_status: :completed).order(:name).map do |set|
      owned = set.cards.joins(:collection_card)
                 .where("collection_cards.quantity > 0 OR collection_cards.foil_quantity > 0")
                 .count
      {
        code: set.code,
        name: set.name,
        cards_in_set: set.cards.count,
        cards_owned: owned,
        completion: "#{(owned.to_f / set.cards.count * 100).round(1)}%"
      }
    end
  end

  def get_set_cards(set_code)
    set = CardSet.find_by!(code: set_code.downcase)
    set.cards.includes(:collection_card).order(:collector_number).map do |card|
      {
        id: card.id,
        name: card.name,
        number: card.collector_number,
        rarity: card.rarity,
        quantity: card.collection_card&.quantity.to_i,
        foil_quantity: card.collection_card&.foil_quantity.to_i
      }
    end
  rescue ActiveRecord::RecordNotFound
    { error: "Set '#{set_code}' not found. Use list_sets to see available sets." }
  end

  def search_cards(query, set_code = nil)
    cards = Card.includes(:collection_card, :card_set)
                .where("cards.name LIKE ?", "%#{query}%")
                .limit(20)

    cards = cards.joins(:card_set).where(card_sets: { code: set_code.downcase }) if set_code.present?

    cards.map do |card|
      {
        id: card.id,
        name: card.name,
        set: card.card_set.name,
        set_code: card.card_set.code,
        number: card.collector_number,
        rarity: card.rarity,
        quantity: card.collection_card&.quantity.to_i,
        foil_quantity: card.collection_card&.foil_quantity.to_i
      }
    end
  end

  def get_owned_cards(set_code = nil)
    cards = Card.includes(:collection_card, :card_set)
                .joins(:collection_card)
                .where("collection_cards.quantity > 0 OR collection_cards.foil_quantity > 0")

    cards = cards.joins(:card_set).where(card_sets: { code: set_code.downcase }) if set_code.present?

    cards.limit(50).map do |card|
      {
        id: card.id,
        name: card.name,
        set: card.card_set.name,
        quantity: card.collection_card.quantity.to_i,
        foil_quantity: card.collection_card.foil_quantity.to_i
      }
    end
  end

  def get_missing_cards(set_code = nil)
    cards = Card.includes(:collection_card, :card_set)
                .left_joins(:collection_card)
                .where("collection_cards.id IS NULL OR (collection_cards.quantity = 0 AND (collection_cards.foil_quantity IS NULL OR collection_cards.foil_quantity = 0))")

    cards = cards.joins(:card_set).where(card_sets: { code: set_code.downcase }) if set_code.present?

    cards.limit(50).map do |card|
      {
        id: card.id,
        name: card.name,
        set: card.card_set.name,
        set_code: card.card_set.code,
        number: card.collector_number,
        rarity: card.rarity
      }
    end
  end

  def update_card_quantity(card_id, quantity, foil_quantity)
    card = Card.includes(:collection_card, :card_set).find(card_id)
    collection = card.collection_card || CollectionCard.new(card: card)

    collection.quantity = quantity if quantity.present?
    collection.foil_quantity = foil_quantity if foil_quantity.present?
    collection.save!

    {
      success: true,
      card: card.name,
      quantity: collection.quantity.to_i,
      foil_quantity: collection.foil_quantity.to_i
    }
  rescue ActiveRecord::RecordNotFound
    { error: "Card not found: #{card_id}" }
  end
end

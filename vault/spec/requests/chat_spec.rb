# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Chat" do
  let(:user) { create(:user, username: "testuser", password: "password123", password_confirmation: "password123") }

  before do
    post login_path, params: { username: user.username, password: "password123" }
  end

  describe "GET /chat" do
    it "renders the chat page" do
      get "/chat"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Collection Assistant")
      expect(response.body).to include("data-controller=\"chat\"")
    end
  end

  describe "POST /chat" do
    let(:mock_service) { instance_double(ChatService) }

    before do
      allow(ChatService).to receive(:new).and_return(mock_service)
    end

    context "with successful response" do
      before do
        allow(mock_service).to receive(:chat).and_return({
          response: "You have 5 sets downloaded with 100 cards total.",
          messages: [
            { role: "user", content: "How many cards do I have?" },
            { role: "assistant", content: "You have 5 sets downloaded with 100 cards total." }
          ]
        })
      end

      it "returns JSON response" do
        post "/chat",
          params: { message: "How many cards do I have?", history: "[]" },
          headers: { "Accept" => "application/json", "Content-Type" => "application/json" },
          as: :json

        expect(response).to have_http_status(:ok)
        json = response.parsed_body

        expect(json["response"]).to include("5 sets downloaded")
        expect(json["history"]).to be_an(Array)
      end

      it "passes message and history to service" do
        history = [ { "role" => "user", "content" => "Previous message" } ]

        post "/chat",
          params: { message: "Follow up question", history: history.to_json },
          headers: { "Accept" => "application/json", "Content-Type" => "application/json" },
          as: :json

        expect(mock_service).to have_received(:chat) do |messages|
          expect(messages.length).to eq(2)
          # Keys may be strings from JSON parsing
          expect(messages[0]["role"] || messages[0][:role]).to eq("user")
          expect(messages[0]["content"] || messages[0][:content]).to eq("Previous message")
          expect(messages[1][:role]).to eq("user")
          expect(messages[1][:content]).to eq("Follow up question")
        end
      end
    end

    context "when service raises an error" do
      before do
        allow(mock_service).to receive(:chat).and_raise(StandardError.new("API error"))
      end

      it "returns error response" do
        post "/chat",
          params: { message: "Test message", history: "[]" },
          headers: { "Accept" => "application/json", "Content-Type" => "application/json" },
          as: :json

        expect(response).to have_http_status(:internal_server_error)
        json = response.parsed_body

        expect(json["response"]).to include("API error")
      end
    end

    context "with empty history" do
      before do
        allow(mock_service).to receive(:chat).and_return({
          response: "Hello!",
          messages: []
        })
      end

      it "handles nil history" do
        post "/chat",
          params: { message: "Hello" },
          headers: { "Accept" => "application/json", "Content-Type" => "application/json" },
          as: :json

        expect(response).to have_http_status(:ok)
      end

      it "handles empty string history" do
        post "/chat",
          params: { message: "Hello", history: "" },
          headers: { "Accept" => "application/json", "Content-Type" => "application/json" },
          as: :json

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "authentication" do
    before do
      delete logout_path
    end

    it "requires authentication for GET /chat" do
      get "/chat"

      expect(response).to redirect_to(login_path)
    end

    it "requires authentication for POST /chat" do
      post "/chat",
        params: { message: "Hello" },
        headers: { "Accept" => "application/json" },
        as: :json

      expect(response).to redirect_to(login_path)
    end
  end
end

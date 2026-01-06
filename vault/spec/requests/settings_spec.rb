# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Settings", type: :request do
  let(:user) { create(:user) }

  before do
    # Log in the user
    post login_path, params: { username: user.username, password: "SecurePassword123!" }
    # Clean up settings before each test
    Setting.delete(Setting::GITHUB_TOKEN)
    Setting.delete(Setting::SHOWCASE_GIST_ID)
  end

  after do
    # Clean up settings after each test
    Setting.delete(Setting::GITHUB_TOKEN)
    Setting.delete(Setting::SHOWCASE_GIST_ID)
  end

  describe "GET /settings" do
    it "returns a successful response" do
      get settings_path
      expect(response).to be_successful
    end

    it "returns HTML" do
      get settings_path
      expect(response.content_type).to include("text/html")
    end

    it "displays settings page" do
      get settings_path
      expect(response.body).to include("Settings")
    end

    it "shows placeholder when no token configured" do
      get settings_path
      expect(response.body).to include("ghp_xxxx...")
      expect(response.body).not_to include("GitHub token configured")
    end

    it "shows GitHub token configured when token exists" do
      Setting.github_token = "test_token"
      get settings_path
      expect(response.body).to include("GitHub token configured")
    end

    it "shows Gist ID when configured" do
      Setting.showcase_gist_id = "abc123"
      get settings_path
      expect(response.body).to include("abc123")
    end
  end

  describe "PATCH /settings" do
    context "with valid token" do
      it "saves the GitHub token" do
        patch settings_path, params: { github_token: "ghp_newtoken123" }
        expect(Setting.github_token).to eq("ghp_newtoken123")
      end

      it "redirects to settings page" do
        patch settings_path, params: { github_token: "ghp_newtoken123" }
        expect(response).to redirect_to(settings_path)
      end

      it "shows success message" do
        patch settings_path, params: { github_token: "ghp_newtoken123" }
        follow_redirect!
        expect(flash[:notice]).to include("GitHub token saved")
      end

      it "stores token encrypted" do
        patch settings_path, params: { github_token: "ghp_secrettoken" }
        raw = Setting.find_by(key: Setting::GITHUB_TOKEN)
        expect(raw.encrypted).to be true
        expect(raw.value).not_to eq("ghp_secrettoken")
      end
    end

    context "with empty token" do
      before do
        Setting.github_token = "existing_token"
      end

      it "removes the GitHub token" do
        patch settings_path, params: { github_token: "" }
        expect(Setting.github_token).to be_nil
      end

      it "shows removed message" do
        patch settings_path, params: { github_token: "" }
        follow_redirect!
        expect(flash[:notice]).to include("removed")
      end
    end

    context "updating existing token" do
      before do
        Setting.github_token = "old_token"
      end

      it "overwrites the existing token" do
        patch settings_path, params: { github_token: "new_token" }
        expect(Setting.github_token).to eq("new_token")
      end
    end
  end

  describe "DELETE /settings/clear_gist_id" do
    before do
      Setting.showcase_gist_id = "existing_gist_123"
    end

    it "clears the Gist ID" do
      delete clear_gist_id_settings_path
      expect(Setting.showcase_gist_id).to be_nil
    end

    it "redirects to settings page" do
      delete clear_gist_id_settings_path
      expect(response).to redirect_to(settings_path)
    end

    it "shows success message" do
      delete clear_gist_id_settings_path
      follow_redirect!
      expect(flash[:notice]).to include("cleared")
    end
  end

  describe "authentication required" do
    before do
      # Log out the user
      delete logout_path
    end

    it "redirects to login for GET /settings" do
      get settings_path
      expect(response).to redirect_to(login_path)
    end

    it "redirects to login for PATCH /settings" do
      patch settings_path, params: { github_token: "token" }
      expect(response).to redirect_to(login_path)
    end

    it "redirects to login for DELETE /settings/clear_gist_id" do
      delete clear_gist_id_settings_path
      expect(response).to redirect_to(login_path)
    end
  end
end

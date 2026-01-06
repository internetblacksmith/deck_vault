# frozen_string_literal: true

require "rails_helper"

RSpec.describe Setting, type: :model do
  describe "validations" do
    subject { Setting.new(key: "test_key", value: "test_value") }

    it { should validate_presence_of(:key) }
    it { should validate_uniqueness_of(:key) }
  end

  describe ".get and .set" do
    it "stores and retrieves a plain text value" do
      Setting.set("test_key", "test_value")
      expect(Setting.get("test_key")).to eq("test_value")
    end

    it "stores and retrieves an encrypted value" do
      Setting.set("secret_key", "secret_value", encrypted: true)

      # Raw value should be encrypted (not equal to original)
      raw = Setting.find_by(key: "secret_key")
      expect(raw.value).not_to eq("secret_value")
      expect(raw.encrypted).to be true

      # But .get should decrypt it
      expect(Setting.get("secret_key")).to eq("secret_value")
    end

    it "returns nil for non-existent key" do
      expect(Setting.get("nonexistent")).to be_nil
    end

    it "overwrites existing value" do
      Setting.set("my_key", "value1")
      Setting.set("my_key", "value2")
      expect(Setting.get("my_key")).to eq("value2")
    end
  end

  describe ".delete" do
    it "removes the setting" do
      Setting.set("to_delete", "value")
      expect(Setting.get("to_delete")).to eq("value")

      Setting.delete("to_delete")
      expect(Setting.get("to_delete")).to be_nil
    end

    it "does nothing for non-existent key" do
      expect { Setting.delete("nonexistent") }.not_to raise_error
    end
  end

  describe ".exists?" do
    it "returns true when setting exists with value" do
      Setting.set("exists_key", "value")
      expect(Setting.exists?("exists_key")).to be true
    end

    it "returns false when setting does not exist" do
      expect(Setting.exists?("nonexistent")).to be false
    end

    it "returns false when setting exists but value is blank" do
      Setting.set("blank_key", "")
      expect(Setting.exists?("blank_key")).to be false
    end
  end

  describe ".github_token" do
    after { Setting.delete(Setting::GITHUB_TOKEN) }

    it "returns value from database" do
      Setting.github_token = "db_token"
      expect(Setting.github_token).to eq("db_token")
    end

    it "falls back to ENV if not in database" do
      allow(ENV).to receive(:[]).with("GITHUB_TOKEN").and_return("env_token")
      expect(Setting.github_token).to eq("env_token")
    end

    it "prefers database over ENV" do
      Setting.github_token = "db_token"
      allow(ENV).to receive(:[]).with("GITHUB_TOKEN").and_return("env_token")
      expect(Setting.github_token).to eq("db_token")
    end

    it "stores token encrypted" do
      Setting.github_token = "my_secret_token"
      raw = Setting.find_by(key: Setting::GITHUB_TOKEN)
      expect(raw.encrypted).to be true
      expect(raw.value).not_to eq("my_secret_token")
    end
  end

   describe ".showcase_gist_id" do
     after { Setting.delete(Setting::SHOWCASE_GIST_ID) }

     it "returns value from database" do
       Setting.showcase_gist_id = "abc123"
       expect(Setting.showcase_gist_id).to eq("abc123")
     end

     it "falls back to ENV if not in database" do
       allow(ENV).to receive(:[]).with("SHOWCASE_GIST_ID").and_return("env_gist")
       expect(Setting.showcase_gist_id).to eq("env_gist")
     end

     it "stores gist_id unencrypted" do
       Setting.showcase_gist_id = "gist123"
       raw = Setting.find_by(key: Setting::SHOWCASE_GIST_ID)
       expect(raw.encrypted).to be false
       expect(raw.value).to eq("gist123")
     end
   end

   describe ".anthropic_api_key" do
     after { Setting.delete(Setting::ANTHROPIC_API_KEY) }

     it "returns value from database" do
       Setting.anthropic_api_key = "sk-ant-test123"
       expect(Setting.anthropic_api_key).to eq("sk-ant-test123")
     end

     it "falls back to ENV if not in database" do
       allow(ENV).to receive(:[]).with("ANTHROPIC_API_KEY").and_return("env_api_key")
       expect(Setting.anthropic_api_key).to eq("env_api_key")
     end

     it "prefers database over ENV" do
       Setting.anthropic_api_key = "db_api_key"
       allow(ENV).to receive(:[]).with("ANTHROPIC_API_KEY").and_return("env_api_key")
       expect(Setting.anthropic_api_key).to eq("db_api_key")
     end

     it "stores API key encrypted" do
       Setting.anthropic_api_key = "sk-ant-secret"
       raw = Setting.find_by(key: Setting::ANTHROPIC_API_KEY)
       expect(raw.encrypted).to be true
       expect(raw.value).not_to eq("sk-ant-secret")
     end
   end

   describe ".chat_model" do
     after { Setting.delete(Setting::CHAT_MODEL) }

     it "returns value from database" do
       Setting.chat_model = "claude-3-opus-20240229"
       expect(Setting.chat_model).to eq("claude-3-opus-20240229")
     end

     it "falls back to ENV if not in database" do
       allow(ENV).to receive(:[]).with("CHAT_MODEL").and_return("claude-3-5-haiku-20241022")
       expect(Setting.chat_model).to eq("claude-3-5-haiku-20241022")
     end

     it "falls back to default if not in database or ENV" do
       allow(ENV).to receive(:[]).with("CHAT_MODEL").and_return(nil)
       expect(Setting.chat_model).to eq(Setting::DEFAULT_CHAT_MODEL)
     end

     it "prefers database over ENV over default" do
       Setting.chat_model = "db_model"
       allow(ENV).to receive(:[]).with("CHAT_MODEL").and_return("env_model")
       expect(Setting.chat_model).to eq("db_model")
     end

     it "stores chat model unencrypted" do
       Setting.chat_model = "claude-3-5-sonnet-20241022"
       raw = Setting.find_by(key: Setting::CHAT_MODEL)
       expect(raw.encrypted).to be false
       expect(raw.value).to eq("claude-3-5-sonnet-20241022")
     end
   end
 end

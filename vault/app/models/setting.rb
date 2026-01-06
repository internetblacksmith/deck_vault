# frozen_string_literal: true

class Setting < ApplicationRecord
  validates :key, presence: true, uniqueness: true

  # Known setting keys
  GITHUB_TOKEN = "github_token"
  SHOWCASE_GIST_ID = "showcase_gist_id"
  ANTHROPIC_API_KEY = "anthropic_api_key"
  CHAT_MODEL = "chat_model"

  # Default values
  DEFAULT_CHAT_MODEL = "claude-sonnet-4-20250514"

  class << self
    # Get a setting value by key
    def get(key)
      setting = find_by(key: key)
      return nil unless setting

      setting.encrypted? ? decrypt(setting.value) : setting.value
    end

    # Set a setting value
    def set(key, value, encrypted: false)
      setting = find_or_initialize_by(key: key)
      setting.value = encrypted ? encrypt(value) : value
      setting.encrypted = encrypted
      setting.save!
      setting
    end

    # Delete a setting
    def delete(key)
      find_by(key: key)&.destroy
    end

    # Check if a setting exists and has a value
    def exists?(key)
      setting = find_by(key: key)
      setting.present? && setting.value.present?
    end

    # Get GitHub token (checks DB first, then ENV)
    def github_token
      get(GITHUB_TOKEN) || ENV["GITHUB_TOKEN"]
    end

    # Set GitHub token
    def github_token=(value)
      if value.present?
        set(GITHUB_TOKEN, value, encrypted: true)
      else
        delete(GITHUB_TOKEN)
      end
    end

    # Get Gist ID (checks DB first, then ENV)
    def showcase_gist_id
      get(SHOWCASE_GIST_ID) || ENV["SHOWCASE_GIST_ID"]
    end

    # Set Gist ID
    def showcase_gist_id=(value)
      if value.present?
        set(SHOWCASE_GIST_ID, value)
      else
        delete(SHOWCASE_GIST_ID)
      end
    end

    # Get Anthropic API key (checks DB first, then ENV)
    def anthropic_api_key
      get(ANTHROPIC_API_KEY) || ENV["ANTHROPIC_API_KEY"]
    end

    # Set Anthropic API key (encrypted)
    def anthropic_api_key=(value)
      if value.present?
        set(ANTHROPIC_API_KEY, value, encrypted: true)
      else
        delete(ANTHROPIC_API_KEY)
      end
    end

    # Get chat model (checks DB first, then ENV, then default)
    def chat_model
      get(CHAT_MODEL) || ENV["CHAT_MODEL"] || DEFAULT_CHAT_MODEL
    end

    # Set chat model
    def chat_model=(value)
      if value.present?
        set(CHAT_MODEL, value)
      else
        delete(CHAT_MODEL)
      end
    end

    private

    # Simple encryption using Rails credentials key
    def encrypt(value)
      return nil if value.blank?

      key = encryption_key
      cipher = OpenSSL::Cipher.new("aes-256-gcm")
      cipher.encrypt
      cipher.key = key
      iv = cipher.random_iv

      encrypted = cipher.update(value) + cipher.final
      tag = cipher.auth_tag

      Base64.strict_encode64(iv + tag + encrypted)
    end

    def decrypt(encrypted_value)
      return nil if encrypted_value.blank?

      key = encryption_key
      decoded = Base64.strict_decode64(encrypted_value)

      cipher = OpenSSL::Cipher.new("aes-256-gcm")
      cipher.decrypt
      cipher.key = key
      cipher.iv = decoded[0, 12]
      cipher.auth_tag = decoded[12, 16]

      cipher.update(decoded[28..]) + cipher.final
    rescue StandardError => e
      Rails.logger.error("Failed to decrypt setting: #{e.message}")
      nil
    end

    def encryption_key
      # Use Rails secret key base, truncated to 32 bytes for AES-256
      secret = Rails.application.secret_key_base || "development_secret_key_base_for_encryption"
      Digest::SHA256.digest(secret)
    end
  end
end

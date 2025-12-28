source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "8.1.1"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft", "1.3.1"
# Use sqlite3 as the database for Active Record
gem "sqlite3", "2.9.0"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", "7.1.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails", "2.2.2"
# Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails", "~> 4.0"
# Hotwire's SPA-like page accelerator [https://github.com/rails/turbo-rails]
gem "turbo-rails", "2.0.20"
# Hotwire's modest JavaScript framework [https://github.com/rails/stimulus-rails]
gem "stimulus-rails", "1.3.4"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder", "2.14.1"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "3.1.20"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache", "1.0.10"
gem "solid_queue", "1.2.4"
gem "solid_cable", "1.1.0"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", "1.20.1", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", "2.10.1", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", "0.1.17", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "1.14.0"

# Scryfall API client
gem "httparty", "0.23.2"

# CSV handling
gem "csv", "3.3.5"

# HTTP requests
gem "faraday", "2.14.0"

# Background job processing
gem "sidekiq", "7.3.10"
gem "redis", "5.4.1"
gem "connection_pool", "2.5.5"

# Environment variables
gem "dotenv-rails", "3.2.0", groups: [:development, :test]

group :development, :test do
   # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
   gem "debug", "1.11.1", platforms: %i[ mri windows ], require: "debug/prelude"

   # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
   gem "bundler-audit", "0.9.3", require: false

   # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
   gem "brakeman", "6.2.2", require: false

   # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
   gem "rubocop-rails-omakase", "1.1.0", require: false
 end

  group :development do
    # Use console on exceptions pages [https://github.com/rails/web-console]
    gem "web-console", "4.2.1"
    
    # Process manager for managing multiple services [https://github.com/ddollar/foreman]
    gem "foreman", "0.90.0"
  end

   group :test do
     # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
     gem "capybara", "3.40.0"
     gem "selenium-webdriver", "4.39.0"

     # RSpec - Unit and integration testing
     gem "rspec-rails", "6.1.1"
     gem "factory_bot_rails", "6.4.0"
     gem "faker", "3.2.3"
     gem "shoulda-matchers", "6.4.0"
     
     # VCR - Record and replay HTTP interactions
     gem "vcr", "6.4.0"
     gem "webmock", "3.26.1"
   end

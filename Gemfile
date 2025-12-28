source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "8.1.1"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft", "~> 1.2"
# Use sqlite3 as the database for Active Record
gem "sqlite3", "~> 2.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", "~> 7.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails", "~> 2.0"
# Hotwire's SPA-like page accelerator [https://github.com/rails/turbo-rails]
gem "turbo-rails", "~> 2.0"
# Hotwire's modest JavaScript framework [https://github.com/rails/stimulus-rails]
gem "stimulus-rails", "~> 1.3"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder", "~> 2.7"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache", "~> 1.0"
gem "solid_queue", "~> 1.0"
gem "solid_cable", "~> 1.0"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", "~> 1.18", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", "~> 2.3", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", "~> 0.1", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.13"

# Scryfall API client
gem "httparty", "~> 0.22"

# CSV handling
gem "csv", "~> 3.2"

# HTTP requests
gem "faraday", "~> 2.10"

# Background job processing
gem "sidekiq", "~> 7.3"
gem "redis", "~> 5.0"
gem "connection_pool", "~> 2.5"

# Environment variables
gem "dotenv-rails", "~> 3.1", groups: [:development, :test]

group :development, :test do
   # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
   gem "debug", "~> 1.10", platforms: %i[ mri windows ], require: "debug/prelude"

   # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
   gem "bundler-audit", "~> 0.9", require: false

   # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
   gem "brakeman", "~> 6.1", require: false

   # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
   gem "rubocop-rails-omakase", "~> 1.1", require: false
 end

 group :development do
   # Use console on exceptions pages [https://github.com/rails/web-console]
   gem "web-console", "~> 4.2"
 end

 group :test do
   # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
   gem "capybara", "~> 3.40"
   gem "selenium-webdriver", "~> 4.18"
 end

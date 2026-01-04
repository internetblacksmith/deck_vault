# Agent Coding Guidelines - Deck Vault Monorepo

This document provides essential guidelines for agentic coding in the Deck Vault monorepo.

## Repository Structure

```
deck_vault/
├── vault/     # Rails app for collection management
├── showcase/      # Static site generator (Astro)
├── seller/        # Cardmarket seller app (Node.js)
├── docker-compose.yml
├── README.md
└── AGENTS.md
```

---

## Collector (Rails App)

**Location:** `vault/`

### Development Setup

**Prerequisites:**
- Ruby 3.4+
- Rails 8.1+
- SQLite3
- Docker (for Redis)

**Initial Setup:**
```bash
cd vault
bundle install
cp .env.example .env
bin/rails db:create db:migrate
docker-compose -f ../docker-compose.yml up -d redis
```

### Build, Test & Lint Commands

All commands should be run from the `vault/` directory.

#### Running Tests (RSpec)
```bash
# Run all tests (298 tests: model + request specs)
bundle exec rspec

# Run specific test suites
bundle exec rspec spec/models                    # Model unit tests
bundle exec rspec spec/requests                  # Controller/request tests
bundle exec rspec spec/requests/auth_spec.rb     # Authentication tests only

# Run with detailed output
bundle exec rspec --format documentation

# With coverage report
COVERAGE=true bundle exec rspec

# Run single test file
bundle exec rspec spec/models/user_spec.rb

# Run tests matching a pattern
bundle exec rspec -e "validations"
```

#### Running Tests (Cucumber - BDD Acceptance Tests)
```bash
# Run all Cucumber scenarios
bundle exec cucumber

# Run specific feature file
bundle exec cucumber features/binder_view.feature

# Run specific scenario by line number
bundle exec cucumber features/binder_view.feature:17

# Run with verbose output
bundle exec cucumber --format pretty

# Run only non-WIP scenarios (default)
bundle exec cucumber --tags 'not @wip'

# Run JavaScript scenarios (requires Chrome/Chromium)
bundle exec cucumber --tags @javascript
```

#### Code Quality
```bash
# Lint with RuboCop (Omakase Rails style)
bin/rubocop

# Auto-fix linting issues
bin/rubocop -A

# Security audit for gems
bin/bundler-audit

# Security scan for vulnerabilities
bin/brakeman
```

### Development Workflow

#### Option 1: Simple Development (Rails + CSS)
```bash
bin/dev
```
Just Rails server with automatic Tailwind CSS rebuilding. No background jobs.

#### Option 2: Full Stack with Separate Redis Terminal
```bash
# Terminal 1: Redis (required for Sidekiq) - from repo root
docker-compose up redis

# Terminal 2: Rails + CSS + Sidekiq (from vault/)
bin/dev --sidekiq
```

#### Option 3: Integrated Full Stack
```bash
# Terminal 1: Redis (from repo root)
docker-compose up redis

# Terminal 2: All services (from vault/)
bin/dev --redis
```

#### Shutdown
```bash
# Stop foreman (Ctrl+C)
# Stop Redis (from repo root)
docker-compose down

# Kill any remaining processes
pkill -f "puma|sidekiq|tailwindcss"
```

### Code Style Guidelines

#### File Organization
- **Models:** `vault/app/models/` - Keep business logic and validations here
- **Controllers:** `vault/app/controllers/` - Handle HTTP requests, keep logic thin
- **Services:** `vault/app/services/` - External API calls and complex operations
- **Jobs:** `vault/app/jobs/` - Background jobs using Sidekiq
- **Helpers:** `vault/app/helpers/` - View helpers only
- **Tests:** `vault/spec/` - RSpec tests

#### Naming Conventions
- **Constants:** `SCREAMING_SNAKE_CASE` - `BASE_URL`, `IMAGES_DIR`
- **Classes:** `PascalCase` - `CardSet`, `ScryfallService`, `DownloadCardImagesJob`
- **Methods:** `snake_case` - `download_progress_percentage`, `all_images_downloaded?`
- **Variables:** `snake_case` - `@card_set`, `card_data`, `images_count`
- **Booleans:** End with `?` - `is_valid?`, `all_images_downloaded?`
- **Database:** `snake_case` - `download_status`, `images_downloaded`

#### Imports & Dependencies
```ruby
# Standard: require statements at top
require "fileutils"

# Rails conventions: use implicit requires
# HTTParty is auto-required via Gemfile

# Order: constants, includes, then class definition
class MyClass < ApplicationRecord
  CONSTANT = "value".freeze
  
  has_many :cards
  validates :code, presence: true
end
```

#### Type Hints & Comments
- Use inline comments for complex logic: `# Skip if already downloaded`
- Document methods with comment above: `# Fetch all Magic: The Gathering sets`
- No explicit type hints (Ruby is dynamically typed)
- Use descriptive variable names instead: `images_count` not `count`

#### Formatting
- **Indentation:** 2 spaces (never tabs)
- **Line length:** Prefer <100 chars, max 120
- **Arrays/Hashes:** Use bracket notation for single-line, proper formatting for multi-line:
  ```ruby
  # Single line
  validates :code, :name, presence: true
  
  # Multi-line
  enum :download_status, {
    pending: "pending",
    downloading: "downloading",
    completed: "completed",
    failed: "failed"
  }
  ```

#### Error Handling
```ruby
# Always use rescue with StandardError (never rescue Exception)
rescue StandardError => e
  Rails.logger.error("Error message: #{e.message}")
  []  # Return sensible default

# Use raise only for re-raising or critical errors
raise if e.critical?

# Specific exception classes for API errors
rescue ActiveRecord::RecordNotFound
  render json: { errors: "Not found" }, status: :not_found
```

#### Database
- Use `has_many`, `belongs_to` associations
- Always add `dependent: :destroy` for cleanup: `has_many :cards, dependent: :destroy`
- Use `validates` for data integrity:
  ```ruby
  validates :code, :name, presence: true
  validates :code, uniqueness: true
  validates :quantity, numericality: { greater_than_or_equal_to: 0 }
  ```
- Use enums for status fields: `enum :download_status, { pending: "pending", ... }`

#### API Integration
- Wrap external API calls in service classes: `ScryfallService`
- Always rescue errors and log them: `rescue StandardError => e`
- Return empty collections on failure: `return [] unless response.success?`
- Use `.freeze` for API URLs: `BASE_URL = "https://...".freeze`

#### Controllers
- Keep thin: delegate to services/models
- Use `before_action` for setup: `before_action :set_card_set, only: [:show]`
- Private helper methods at bottom: `private` separator
- JSON responses use consistent format:
  ```ruby
  render json: { success: true, data: object }
  render json: { errors: errors }, status: :unprocessable_entity
  ```

#### Views
- Use data attributes for JavaScript: `data-card-id="<%= card.id %>"`
- Prefer conditional operators: `@status == 'active' ? 'green' : 'red'`
- Auto-escape variables (Rails default is safe)

#### Background Jobs (Sidekiq)
- Use `queue_as :default` for most jobs
- Add retries: `sidekiq_options retry: 3`
- Log success and failures: `Rails.logger.info/warn/error`
- Always rescue and re-raise: `rescue StandardError => e; raise`
- Update progress in database if needed

#### Testing with RSpec
- Test file mirrors source: `app/models/card.rb` → `spec/models/card_spec.rb`
- Use FactoryBot factories for test data: `create(:card), build(:user)`
- Use shoulda-matchers for model testing: `validate_presence_of(:email)`
- Descriptive test names: `'returns 0 when card_count is zero'`
- Happy path, sad path, and edge case coverage
- Request tests should login users: create user and POST to login route first
- Use `before do` for common setup in request tests

#### Gems & Dependencies
- Keep versions flexible but safe: `gem "rails", "~> 8.1.1"` not exact versions
- Group gems by environment: `group :development, :test do`
- Use `bundle update` sparingly, prefer `bundle install`
- Check compatibility before upgrading: `connection_pool ~> 2.3` (verified with Sidekiq 7.1)

### Project-Specific Patterns

#### Authentication
- Uses custom bcrypt authentication (no Devise needed)
- `ApplicationController#authenticate_user` protects all routes by default
- `SessionsController` handles login/logout
- `RegistrationsController` handles signup
- Routes: GET/POST `/login`, GET/POST `/sign_up`, DELETE `/logout`
- User model: `has_secure_password`, username validation
- Session stored in encrypted Rails cookie
- Test helper: Login users in request specs with `post login_path, params: { username:, password: }`

#### Chat Feature (Claude AI)
The app includes an AI chat assistant powered by Claude for natural language collection queries.

**Location:** `vault/app/services/chat_service.rb`, `vault/app/controllers/chat_controller.rb`

**Setup:**
```bash
# Add to .env
ANTHROPIC_API_KEY=sk-ant-...
```

**Routes:** `GET /chat`, `POST /chat`

**ChatService Tools:**
- `get_collection_stats` - Collection statistics
- `list_sets` - List downloaded sets  
- `get_set_cards` - Cards in a specific set
- `search_cards` - Search by name/set
- `get_owned_cards` - Cards you own
- `get_missing_cards` - Cards you don't own
- `update_card_quantity` - Update quantities

**Testing:**
```bash
bundle exec rspec spec/requests/chat_spec.rb
bundle exec rspec spec/services/chat_service_spec.rb
```

#### API v1 Endpoints
RESTful JSON API for programmatic access.

**Location:** `vault/app/controllers/api/v1/`

**Endpoints:**
```
GET  /api/v1/stats              # Collection statistics
GET  /api/v1/sets               # List completed sets
GET  /api/v1/sets/:code         # Set details with cards
POST /api/v1/sets/download      # Download new set from Scryfall
GET  /api/v1/cards              # Search/filter cards
GET  /api/v1/cards/:id          # Card details
PATCH /api/v1/cards/:id         # Update card quantity
```

**Query Parameters for `/api/v1/cards`:**
- `q` - Search by card name
- `set` - Filter by set code
- `rarity` - Filter by rarity (common, uncommon, rare, mythic)
- `owned=true` - Only owned cards
- `missing=true` - Only missing cards
- `limit` - Max results (default 100, max 500)

**Testing:**
```bash
bundle exec rspec spec/requests/api/v1/
```

#### Delver Lens Import
Import collections from Delver Lens CSV exports.

**Location:** `vault/app/services/delver_csv_import_service.rb`

**Features:**
- Parses Delver Lens CSV format (Name, Set code, Foil, Quantity, Scryfall ID)
- Auto-downloads missing sets from Scryfall
- Two modes: "add" (merge quantities) or "replace" (clear and import)
- Handles foil cards correctly

**Route:** `POST /card_sets/import_delver_csv`

**Testing:**
```bash
bundle exec cucumber features/delver_import.feature
```

#### Scryfall Integration
- Use `ScryfallService` for all API calls
- Always handle pagination: `has_more` flag
- Download images asynchronously: queue `DownloadCardImagesJob`
- Cache responses with timestamp checks

#### Background Jobs
- Queue in controller: `DownloadCardImagesJob.perform_later(card_id)`
- Progress tracking: update `card_set.images_downloaded` and `download_status`
- Ensure idempotence: check `image_path.present?` before downloading

#### Database Queries
- Use `includes` to prevent N+1: `@cards.includes(:collection_card)`
- Use `where.not` for negation: `cards.where.not(image_path: nil)`
- Count efficiently: `CardSet.count` not loading all

#### MCP Server (Model Context Protocol)
The vault app includes a built-in MCP server for LLM integration (Claude Desktop, etc.).

**Location:** `vault/app/mcp/tools/`

**Running the MCP Server:**
```bash
cd vault
bin/mcp_server
```

**Claude Desktop Configuration:**
Add to your Claude Desktop config (`~/.config/claude/claude_desktop_config.json`):
```json
{
  "mcpServers": {
    "deck-vault": {
      "command": "/path/to/vault/bin/mcp_server",
      "args": []
    }
  }
}
```

**Available Tools:**
- `get_collection_stats` - Get collection statistics
- `list_sets` - List all downloaded sets
- `get_set_details` - Get cards in a specific set
- `search_cards` - Search cards by name/set/rarity
- `get_owned_cards` - Get cards you own
- `get_missing_cards` - Get cards you don't own
- `update_card_quantity` - Update card quantities

**Creating New Tools:**
```ruby
# app/mcp/tools/my_tool.rb
module Mcp
  module Tools
    class MyTool < MCP::Tool
      tool_name "my_tool"
      description "Description of what the tool does"

      input_schema(
        properties: {
          param_name: { type: "string", description: "Param description" }
        },
        required: ["param_name"]
      )

      class << self
        def call(param_name:, server_context:)
          # Tool implementation using Rails models
          result = { data: "result" }
          MCP::Tool::Response.new([{
            type: "text",
            text: JSON.pretty_generate(result)
          }])
        end
      end
    end
  end
end
```

---

## Showcase (Astro Static Site)

**Location:** `showcase/`
**Status:** Planned

### Tech Stack
- Astro
- TypeScript
- Tailwind CSS

### Commands (planned)
```bash
cd showcase
npm install
npm run dev        # Development server
npm run build      # Build static site
npm run preview    # Preview built site
```

---

## Seller (Node.js App)

**Location:** `seller/`
**Status:** Planned

### Tech Stack
- Node.js + Express
- TypeScript
- SQLite
- Cardmarket API

### Commands (planned)
```bash
cd seller
npm install
npm run dev        # Development server
npm run build      # Build for production
```

---

## Git & Commits

- Write clear commit messages: "Add feature" or "Fix bug: description"
- Reference related code: include file paths in messages
- One logical change per commit
- Never force push without explicit request
- Prefix commits with project when relevant: `[vault] Add export endpoint`

## Debugging

### Collector
- Use Rails logger: `Rails.logger.info("message")`
- Check development log: `tail -f vault/log/development.log`
- Use `rails console` for debugging (from vault/)
- Check Redis: `docker-compose exec redis redis-cli`
- Monitor Sidekiq: `bundle exec sidekiq -v` shows connected/processing

## Documentation

- Update root README.md for monorepo-level changes
- Update vault/README.md for vault-specific changes
- Update SIDEKIQ_SETUP.md for infrastructure changes
- Add inline comments for non-obvious logic
- Keep AGENTS.md current with code changes

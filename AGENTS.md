# Agent Coding Guidelines - MTG Collection Manager

This document provides essential guidelines for agentic coding in the MTG Collection Manager codebase.

## Development Setup

**Prerequisites:**
- Ruby 3.4+
- Rails 8.1+
- SQLite3
- Docker (for Redis)

**Initial Setup:**
```bash
bundle install
cp .env.example .env
bin/rails db:create db:migrate
docker-compose up -d redis
```

## Build, Test & Lint Commands

### Running Tests (RSpec)
```bash
# Run all tests (242 tests: 127 model + 115 request)
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

### Code Quality
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

#### Option 1: Simplified (Redis + Rails)
```bash
# Terminal 1: Redis
docker-compose up redis

# Terminal 2: Rails Server (with auto CSS rebuild)
bin/dev
```

#### Option 2: Full Stack (Redis + Rails + Sidekiq)
```bash
# Terminal 1: Redis
docker-compose up redis

# Terminal 2: Rails Server with CSS watcher
bin/dev

# Terminal 3: Sidekiq Worker
bundle exec sidekiq -c 5 -v
```

#### Shutdown
```bash
docker-compose down
pkill -f "puma|sidekiq|tailwindcss"
```

## Code Style Guidelines

### File Organization
- **Models:** `app/models/` - Keep business logic and validations here
- **Controllers:** `app/controllers/` - Handle HTTP requests, keep logic thin
- **Services:** `app/services/` - External API calls and complex operations
- **Jobs:** `app/jobs/` - Background jobs using Sidekiq
- **Helpers:** `app/helpers/` - View helpers only
- **Tests:** `test/` - Unit tests, integration tests, system tests

### Naming Conventions
- **Constants:** `SCREAMING_SNAKE_CASE` - `BASE_URL`, `IMAGES_DIR`
- **Classes:** `PascalCase` - `CardSet`, `ScryfallService`, `DownloadCardImagesJob`
- **Methods:** `snake_case` - `download_progress_percentage`, `all_images_downloaded?`
- **Variables:** `snake_case` - `@card_set`, `card_data`, `images_count`
- **Booleans:** End with `?` - `is_valid?`, `all_images_downloaded?`
- **Database:** `snake_case` - `download_status`, `images_downloaded`

### Imports & Dependencies
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

### Type Hints & Comments
- Use inline comments for complex logic: `# Skip if already downloaded`
- Document methods with comment above: `# Fetch all Magic: The Gathering sets`
- No explicit type hints (Ruby is dynamically typed)
- Use descriptive variable names instead: `images_count` not `count`

### Formatting
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

### Error Handling
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

### Database
- Use `has_many`, `belongs_to` associations
- Always add `dependent: :destroy` for cleanup: `has_many :cards, dependent: :destroy`
- Use `validates` for data integrity:
  ```ruby
  validates :code, :name, presence: true
  validates :code, uniqueness: true
  validates :quantity, numericality: { greater_than_or_equal_to: 0 }
  ```
- Use enums for status fields: `enum :download_status, { pending: "pending", ... }`

### API Integration
- Wrap external API calls in service classes: `ScryfallService`
- Always rescue errors and log them: `rescue StandardError => e`
- Return empty collections on failure: `return [] unless response.success?`
- Use `.freeze` for API URLs: `BASE_URL = "https://...".freeze`

### Controllers
- Keep thin: delegate to services/models
- Use `before_action` for setup: `before_action :set_card_set, only: [:show]`
- Private helper methods at bottom: `private` separator
- JSON responses use consistent format:
  ```ruby
  render json: { success: true, data: object }
  render json: { errors: errors }, status: :unprocessable_entity
  ```

### Views
- Use data attributes for JavaScript: `data-card-id="<%= card.id %>"`
- Prefer conditional operators: `@status == 'active' ? 'green' : 'red'`
- Auto-escape variables (Rails default is safe)

### Background Jobs (Sidekiq)
- Use `queue_as :default` for most jobs
- Add retries: `sidekiq_options retry: 3`
- Log success and failures: `Rails.logger.info/warn/error`
- Always rescue and re-raise: `rescue StandardError => e; raise`
- Update progress in database if needed

### Testing with RSpec
- Test file mirrors source: `app/models/card.rb` → `spec/models/card_spec.rb`
- Use FactoryBot factories for test data: `create(:card), build(:user)`
- Use shoulda-matchers for model testing: `validate_presence_of(:email)`
- Descriptive test names: `'returns 0 when card_count is zero'`
- Happy path, sad path, and edge case coverage
- Request tests should login users: create user and POST to login route first
- Use `before do` for common setup in request tests

### Gems & Dependencies
- Keep versions flexible but safe: `gem "rails", "~> 8.1.1"` not exact versions
- Group gems by environment: `group :development, :test do`
- Use `bundle update` sparingly, prefer `bundle install`
- Check compatibility before upgrading: `connection_pool ~> 2.3` (verified with Sidekiq 7.1)

## Project-Specific Patterns

### Authentication
- Uses custom bcrypt authentication (no Devise needed)
- `ApplicationController#authenticate_user` protects all routes by default
- `SessionsController` handles login/logout
- `RegistrationsController` handles signup
- Routes: GET/POST `/login`, GET/POST `/sign_up`, DELETE `/logout`
- User model: `has_secure_password`, email validation with RFC regex
- Session stored in encrypted Rails cookie
- Test helper: Login users in request specs with `post login_path, params: { email:, password: }`

### Scryfall Integration
- Use `ScryfallService` for all API calls
- Always handle pagination: `has_more` flag
- Download images asynchronously: queue `DownloadCardImagesJob`
- Cache responses with timestamp checks

### Background Jobs
- Queue in controller: `DownloadCardImagesJob.perform_later(card_id)`
- Progress tracking: update `card_set.images_downloaded` and `download_status`
- Ensure idempotence: check `image_path.present?` before downloading

### Database Queries
- Use `includes` to prevent N+1: `@cards.includes(:collection_card)`
- Use `where.not` for negation: `cards.where.not(image_path: nil)`
- Count efficiently: `CardSet.count` not loading all

## Git & Commits

- Write clear commit messages: "Add feature" or "Fix bug: description"
- Reference related code: include file paths in messages
- One logical change per commit
- Never force push without explicit request

## Debugging

- Use Rails logger: `Rails.logger.info("message")`
- Check development log: `tail -f log/development.log`
- Use `rails console` for debugging
- Check Redis: `docker-compose exec redis redis-cli`
- Monitor Sidekiq: `bundle exec sidekiq -v` shows connected/processing

## Documentation

- Update README.md for user-facing changes
- Update SIDEKIQ_SETUP.md for infrastructure changes
- Add inline comments for non-obvious logic
- Keep AGENTS.md current with code changes

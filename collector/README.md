# MTG Collection Manager

A Rails web application for managing your Magic: The Gathering card collection. Download card sets from Scryfall's API and track which cards you own, how many copies you have, and where they're stored in your binder.

## Features

### Core Collection Management
- **Authentication**: Secure account creation and login with bcrypt password hashing
- **Download Sets**: Fetch complete card lists from Scryfall API for any Magic set
- **Background Image Downloads**: Uses Sidekiq to download images asynchronously without blocking requests
- **Local Image Caching**: Automatically download and cache all card images locally for offline access
- **Collection Tracking**: Mark cards as owned and track quantity (regular and foil) of copies
- **Binder Management**: Organize cards by binder page number for easy physical organization
- **Multiple Views**:
   - **Table View**: Detailed list with all card information
   - **Grid View**: Card images in a compact grid layout with local caching
   - **Binder Pages View**: Cards organized by page number with visual card previews
- **Card Information**: Complete details including mana cost, type, rarity, and official artwork
- **Offline Ready**: Once downloaded, all card images are cached locally and don't require internet connection to view

### AI-Powered Features
- **Chat Assistant**: Built-in Claude AI chat to query your collection using natural language
  - Ask questions like "What rare cards am I missing from Zendikar?"
  - Update card quantities through conversation
  - Get collection statistics and recommendations

### Import/Export
- **Delver Lens Import**: Import your collection from Delver Lens CSV exports
  - Automatically downloads missing sets from Scryfall
  - Supports "Add to collection" or "Replace collection" modes
  - Handles foil cards correctly

### Developer Features
- **REST API v1**: Full JSON API for programmatic access
- **MCP Server**: Model Context Protocol server for LLM integration (Claude Desktop, etc.)
- **Modern Architecture**: Built with Rails 8.1, Hotwire (Turbo + Stimulus), real-time updates with ActionCable

## Requirements

- Ruby 3.4+
- Rails 8.1+
- SQLite3
- Redis (for background image downloads)
- Sidekiq (included in Gemfile)

## Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd mtg_collector
```

2. Install dependencies:
```bash
bundle install
```

3. Create and initialize the database:
```bash
bin/rails db:create db:migrate
```

4. Start Redis using Docker Compose:
```bash
docker-compose up redis
```

Or run in background:
```bash
docker-compose up -d redis
```

5. Start the development server:
```bash
bin/rails server
```

6. In another terminal, start Sidekiq worker:
```bash
bundle exec sidekiq -c 5 -v
```

7. Open your browser and navigate to `http://localhost:3000`

8. On first access, you'll be prompted to create an account:
   - Sign up with an email and password
   - After creation, you'll be logged in automatically
   - Use these credentials to log in on future visits

## Development Setup

For development, you need three terminals running:

**Terminal 1: Redis (Docker Compose)**
```bash
docker-compose up redis
```

**Terminal 2: Rails Server**
```bash
bin/rails server
```

**Terminal 3: Sidekiq Worker**
```bash
bundle exec sidekiq -c 5 -v
```

### Docker Compose Benefits
- No need to install Redis locally
- Works consistently across macOS, Linux, and Windows
- Easy to start/stop
- Data persists between restarts
- Uses minimal Alpine Linux image

See [SIDEKIQ_SETUP.md](SIDEKIQ_SETUP.md) for detailed Sidekiq configuration and troubleshooting.

## Usage

### Downloading a Set

1. Navigate to the home page to see available sets from Scryfall
2. Click the "Download" button next to any set you want to manage
3. The app will fetch all cards from that set and save them to your database

### Managing Your Collection

1. Click on a downloaded set to view all its cards
2. Use the view selector to switch between Table, Grid, or Binder Pages view

#### Table View
- See all card details in a spreadsheet format
- Enter quantity of copies you own
- Assign page numbers where cards are stored in your binder
- Add notes for each card

#### Grid View
- Visual grid display of card images
- Quick quantity and page assignment
- Great for visual browsing

#### Binder Pages View
- Cards organized by assigned page numbers
- See at a glance what's on each page
- Perfect for physical organization of your collection

### Tracking Card Ownership

For each card you own:
1. Enter the **Quantity** (number of copies)
2. Assign a **Page #** (where it's stored in your binder, 1-200)
3. Optional: Add **Notes** (condition, special edition, etc.)

Changes are auto-saved when you modify the inputs.

## API Integration

This app uses the **Scryfall API** to fetch card data:
- Card names, types, mana costs, and abilities
- Official card images (automatically downloaded and cached locally)
- Rarity information
- Collector numbers

Learn more: https://scryfall.com/docs/api

### Image Caching

When you download a set, the app automatically:
1. Downloads all card images from Scryfall servers
2. Stores them locally in `storage/card_images/` directory
3. Creates an index of local paths in the database
4. Serves images from local storage when viewing cards

**Benefits:**
- No internet connection needed to view card images after initial download
- Faster loading times compared to remote URLs
- Reduced bandwidth usage
- Complete offline access to your collection

**Storage Requirements:**
- Typical set: ~20-50 MB depending on card count
- Example: 265-card Dominaria set = ~24 MB

## Database Schema

### CardSet
- `code`: Set code (e.g., "tla" for Avatar: The Last Airbender)
- `name`: Full set name
- `released_at`: Release date
- `card_count`: Total cards in set
- `scryfall_uri`: Link to Scryfall

### Card
- `card_set_id`: Reference to CardSet
- `name`: Card name
- `mana_cost`: Mana cost (e.g., "{2}{U}{R}")
- `type_line`: Card type and subtype
- `oracle_text`: Card abilities/text
- `rarity`: Card rarity (common, uncommon, rare, mythic)
- `scryfall_id`: Unique Scryfall identifier
- `image_uris`: JSON field with remote card image URLs (for fallback)
- `image_path`: Local path to downloaded card image (e.g., `card_images/[scryfall-id].jpg`)
- `collector_number`: Card number within set

### CollectionCard
- `card_id`: Reference to Card
- `quantity`: Number of copies owned
- `page_number`: Binder page location
- `notes`: Custom notes

## Chat Assistant

The app includes an AI-powered chat assistant that can help you manage your collection:

1. Click "Chat" in the navigation bar
2. Ask questions in natural language:
   - "How many cards do I have?"
   - "Show me my rare cards from the Alpha set"
   - "What cards am I missing from Zendikar?"
   - "Add 4 copies of Lightning Bolt to my collection"

**Requirements**: Set your Anthropic API key in `.env`:
```
ANTHROPIC_API_KEY=sk-ant-...
```

## API Endpoints

The app provides a REST API for programmatic access:

### Stats
- `GET /api/v1/stats` - Collection statistics

### Sets
- `GET /api/v1/sets` - List all downloaded sets
- `GET /api/v1/sets/:code` - Get set details with cards
- `POST /api/v1/sets/download` - Download a new set from Scryfall

### Cards
- `GET /api/v1/cards` - Search/filter cards
  - Query params: `q` (search), `set`, `rarity`, `owned`, `missing`, `limit`
- `GET /api/v1/cards/:id` - Get card details
- `PATCH /api/v1/cards/:id` - Update card quantity

## MCP Server (Model Context Protocol)

The app includes an MCP server for LLM integration with tools like Claude Desktop.

### Running the MCP Server
```bash
bin/mcp_server
```

### Claude Desktop Configuration
Add to `~/.config/claude/claude_desktop_config.json`:
```json
{
  "mcpServers": {
    "mtg-collector": {
      "command": "/path/to/collector/bin/mcp_server",
      "args": []
    }
  }
}
```

### Available Tools
- `get_collection_stats` - Get collection statistics
- `list_sets` - List all downloaded sets
- `get_set_details` - Get cards in a specific set
- `search_cards` - Search cards by name/set/rarity
- `get_owned_cards` - Get cards you own
- `get_missing_cards` - Get cards you don't own
- `update_card_quantity` - Update card quantities

## Delver Lens Import

Import your collection from Delver Lens:

1. Export your collection from Delver Lens as CSV
2. In the app, click "Import/Export" 
3. Choose "Import Delver CSV"
4. Select your mode:
   - **Add to collection**: Merges with existing quantities
   - **Replace collection**: Clears existing and imports fresh
5. Upload your CSV file

The import will automatically download any missing sets from Scryfall.

## Future Enhancements

- Export collection as CSV/PDF
- Card valuation integration
- Wishlist feature
- Trade list management

## Testing

This project has comprehensive test coverage with automated tests covering models, requests, services, and features.

### Run All Tests
```bash
# RSpec unit and request tests
bundle exec rspec

# Cucumber BDD acceptance tests
bundle exec cucumber
```

### Run Specific Test Suites
```bash
# Model unit tests
bundle exec rspec spec/models

# Controller/request tests
bundle exec rspec spec/requests

# API v1 endpoint tests
bundle exec rspec spec/requests/api/v1

# Service tests (ChatService, Scryfall)
bundle exec rspec spec/services

# MCP tools tests
bundle exec rspec spec/mcp

# Cucumber features
bundle exec cucumber features/binder_view.feature
bundle exec cucumber features/card_search.feature
bundle exec cucumber features/delver_import.feature

# With coverage report
COVERAGE=true bundle exec rspec
```

### Test Coverage
- **Models**: User, CardSet, Card, CollectionCard
- **Requests**: Authentication, CardSets, Chat, API v1 (Stats, Sets, Cards)
- **Services**: ChatService, ScryfallService
- **MCP Tools**: All 7 collection management tools
- **Features**: Binder view, card search, Delver import

## Development

Lint code:
```bash
bin/rubocop
```

Security audit:
```bash
bin/brakeman
bin/bundler-audit
```

## Architecture

### Rails 8.1 Modern Stack
- **Frontend**: Hotwire (Turbo 2.0 + Stimulus 1.3) for fast, responsive UI without SPAs
- **Real-time**: ActionCable with Turbo Streams for live progress updates
- **Caching**: Fragment caching with HTTP cache headers (24h for completed sets, 0s for downloading)
- **Background Jobs**: Sidekiq for asynchronous image downloads
- **Database**: SQLite3 for simplicity and offline capability
- **Authentication**: bcrypt for secure password hashing

### Authentication
- Custom auth implementation (no Devise needed for this simple case)
- Sessions stored in encrypted Rails session cookie
- Password hashing with bcrypt (3.1.20)
- Email validation with RFC standard regex
- Protected routes with `authenticate_user` before_action
- Automatic redirect to login for unauthenticated access

### API Integration
Scryfall API integration for card data:
- Paginated set fetching
- Card details and images
- Error handling and retries
- VCR cassettes for test mocking

### Code Quality
- 242 automated tests (RSpec with FactoryBot)
- shoulda-matchers for model testing
- 100% test coverage for critical paths
- RuboCop Omakase Rails style guide compliance

## License

MIT

# MTG Collection Manager

A Rails web application for managing your Magic: The Gathering card collection. Download card sets from Scryfall's API and track which cards you own, how many copies you have, and where they're stored in your binder.

## Features

- **Download Sets**: Fetch complete card lists from Scryfall API for any Magic set
- **Collection Tracking**: Mark cards as owned and track quantity of copies
- **Binder Management**: Organize cards by binder page number for easy physical organization
- **Multiple Views**:
  - **Table View**: Detailed list with all card information
  - **Grid View**: Card images in a compact grid layout
  - **Binder Pages View**: Cards organized by page number for visual reference
- **Card Information**: Complete details including mana cost, type, rarity, and official artwork

## Requirements

- Ruby 3.4+
- Rails 8.1+
- SQLite3

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

4. Start the development server:
```bash
bin/rails server
```

5. Open your browser and navigate to `http://localhost:3000`

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
- Official card images
- Rarity information
- Collector numbers

Learn more: https://scryfall.com/docs/api

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
- `image_uris`: JSON field with card images
- `collector_number`: Card number within set

### CollectionCard
- `card_id`: Reference to Card
- `quantity`: Number of copies owned
- `page_number`: Binder page location
- `notes`: Custom notes

## Future Enhancements

- Export collection as CSV/PDF
- Card search and filtering
- Set completion percentage
- Bulk import functionality
- Card valuation integration
- Wishlist feature
- User accounts and multi-collection support

## Development

Run tests:
```bash
bin/rails test
```

Lint code:
```bash
bin/rubocop
```

Security audit:
```bash
bin/brakeman
bin/bundler-audit
```

## License

MIT

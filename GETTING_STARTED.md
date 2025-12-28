# Getting Started with MTG Collection Manager

This guide will help you set up and start using the MTG Collection Manager to track your Magic: The Gathering collection.

## Prerequisites

- Ruby 3.4 or higher
- SQLite3
- Basic terminal knowledge

## Installation & Setup

### 1. Clone and Install

```bash
git clone <repository-url>
cd mtg_collector
bundle install
```

### 2. Initialize Database

```bash
bin/rails db:create db:migrate
```

### 3. Start the Server

#### Option A: Simple (Rails + CSS only)
```bash
bin/dev
```
Runs Rails server with automatic Tailwind CSS rebuilding.

#### Option B: Full App (Rails + CSS + Sidekiq)
```bash
bin/dev --sidekiq
```
Includes background job processing. Make sure Redis is running:
```bash
docker-compose up -d redis
```

#### Option C: Complete (Rails + CSS + Sidekiq + Redis)
```bash
# Terminal 1: Start Redis
docker-compose up redis

# Terminal 2: Start all services
bin/dev --redis
```

The app will be available at `http://localhost:3000`

**Recommended for development:** Use `bin/dev --sidekiq` with Redis running separately for the full app experience.

### 4. Create Your Account

On first visit:
1. Go to `http://localhost:3000`
2. You'll be redirected to the login page
3. Click "Sign up" to create a new account
4. Enter your email and a secure password
5. After creation, you'll be logged in automatically

**Note:** The app uses secure bcrypt password hashing. Your password is never stored in plain text.

## Your First Steps

### Step 1: List Available Sets

To see all available Magic sets from Scryfall:

```bash
bin/rails scryfall:list_sets
```

This shows all sets with their card counts. Look for sets you want to manage:
- `✗` = Not yet downloaded
- `✓` = Already downloaded

### Step 2: Download Your First Set

Download a set using its code (e.g., "dom" for Dominaria):

```bash
bin/rails scryfall:download_set[dom]
```

**What happens during download:**
- Card data (name, type, rarity, etc.) is fetched from Scryfall API
- All card images are automatically downloaded and saved locally
- Database is updated with card information and local image paths

**First time setup note:** Initial download may take 1-5 minutes depending on set size and internet speed. The app downloads images in the background while parsing card data.

Or through the web interface:
1. Go to `http://localhost:3000`
2. Find the set in "Available Sets"
3. Click the "Download" button
4. Wait for completion message

### Step 3: Track Your Cards

Once downloaded:
1. Click on the set name to view all cards
2. For each card you own:
   - Enter the **Quantity** (how many copies)
   - Assign a **Page #** (where it's stored in your binder)
   - Add optional **Notes**

### Step 4: Visualize Your Collection

Choose your preferred view:
- **Table View**: See all details in spreadsheet format
- **Grid View**: Browse with card images
- **Binder Pages View**: See cards organized by page number

## Common Tasks

### Download Multiple Sets

```bash
bin/rails scryfall:download_set[tla]
bin/rails scryfall:download_set[tle]
bin/rails scryfall:download_set[ttla]
```

### Check Your Collection Progress

```bash
bin/rails scryfall:set_status[tla]
```

This shows:
- Total cards in set
- Cards you own
- Collection completion percentage

### Update Card Information

In the web interface, cards auto-save when you:
- Type a quantity
- Enter a page number
- Add notes

### Browse Your Collection

1. Go to "My Collection" on the home page
2. Click on any set name
3. Switch between views using the buttons at the top

## Tips & Tricks

### Organizing by Binder Pages

Magic binders typically have 9 card slots per page. To organize:
- Pages 1-50: Creatures
- Pages 51-100: Spells
- Pages 101+: Lands/Other

The Binder Pages view will show cards grouped exactly as they appear in your binder.

### Using Notes

Add custom notes like:
- Card condition (mint, near mint, lightly played, etc.)
- Special edition or foil status
- Trading information
- Any other collection notes

### Filtering Cards

In the current version, all cards in a set are shown. You can:
- Use your browser's find function (Ctrl+F) to search
- Sort cards using the Table view headers

### Offline Usage

Once you've downloaded a set:
- All card images are cached locally
- You can browse your collection **without internet connection**
- Just keep the Rails server running with `bin/rails server`
- Access the app at `http://localhost:3000` anytime

**Note:** You'll need internet connection only when:
- Downloading new sets from Scryfall
- First time setting up the app

## Storage Tips

Card images are stored in `storage/card_images/`:
- Each image is typically 70-100 KB
- A typical set uses 20-50 MB of disk space
- Images are cached permanently until you delete them

To see how much space your images use:
```bash
du -sh storage/card_images/
```

## Troubleshooting

### Server Won't Start

Make sure port 3000 is available:
```bash
# Kill any process using port 3000
lsof -ti:3000 | xargs kill -9
```

### Database Errors

Reset the database:
```bash
bin/rails db:drop db:create db:migrate
```

### Set Download Fails

- Check your internet connection
- Make sure the set code is correct (check with `bin/rails scryfall:list_sets`)
- Try again - Scryfall API might be temporarily unavailable

## Next Steps

- Download all your sets and start tracking cards
- Explore different visualization options
- Export your collection data (coming soon!)

## Need Help?

Check the main [README.md](README.md) for:
- Feature details
- Database schema information
- Development setup
- Future enhancement plans

Enjoy managing your collection!

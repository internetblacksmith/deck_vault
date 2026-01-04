# Publishing Your Collection to Showcase

This guide explains how to publish your MTG collection from the Collector app to the Showcase static site using GitHub Gist as a bridge.

## How It Works

```
┌─────────────┐     publish      ┌─────────────┐     fetch       ┌─────────────┐
│  Collector  │ ──────────────> │ GitHub Gist │ <────────────── │  Showcase   │
│  (local)    │                 │  (cloud)    │   (build time)  │  (deployed) │
└─────────────┘                 └─────────────┘                 └─────────────┘
```

1. **Collector** runs locally on your machine
2. Click "Publish to Showcase" to upload your collection data to a **GitHub Gist**
3. **Showcase** fetches the data from the Gist when it builds/deploys

This allows the Showcase site (hosted on Netlify, Vercel, GitHub Pages, etc.) to display your collection without needing direct access to your local Collector app.

## Setup (One-Time)

### Step 1: Create a GitHub Personal Access Token

1. Go to [GitHub Token Settings](https://github.com/settings/tokens/new?scopes=gist)
2. Give it a name like "Deck Vault"
3. Select the **gist** scope (should be pre-selected from link above)
4. Click "Generate token"
5. **Copy the token** (starts with `ghp_...`) - you won't see it again!

### Step 2: Add Token to Collector

Add to your `vault/.env` file:

```env
GITHUB_TOKEN=ghp_your_token_here
```

If using Docker, restart the containers:
```bash
docker-compose down && docker-compose up -d
```

### Step 3: First Publish

1. Open Collector at http://localhost:3000
2. On the main page, click **"Publish to Showcase"**
3. You'll see a success message with your new Gist ID
4. Copy the Gist ID and add it to your `.env`:

```env
GITHUB_TOKEN=ghp_your_token_here
SHOWCASE_GIST_ID=abc123def456...
```

This saves the Gist ID so future publishes update the same Gist instead of creating new ones.

### Step 4: Configure Showcase

Add the Gist URL to your Showcase environment:

**For local development** (`showcase/.env`):
```env
PUBLIC_GIST_URL=https://gist.githubusercontent.com/raw/YOUR_GIST_ID/mtg_collection.json
```

**For Netlify/Vercel deployment:**
Add `PUBLIC_GIST_URL` as an environment variable in your hosting dashboard.

## Publishing Updates

After the initial setup, publishing is simple:

1. Make changes to your collection in Collector
2. Click **"Publish to Showcase"**
3. Wait for Showcase to rebuild (automatic if using Netlify/Vercel with auto-deploy)

That's it! Your changes will appear on the Showcase site after rebuild.

## Troubleshooting

### "GITHUB_TOKEN not configured"

Make sure you've added the token to `vault/.env` and restarted the app/containers.

### "GitHub API error: Bad credentials"

Your token may have expired or been revoked. Create a new one at [GitHub Token Settings](https://github.com/settings/tokens/new?scopes=gist).

### "GitHub API error: Not Found"

If you're trying to update an existing Gist, make sure `SHOWCASE_GIST_ID` is correct and the Gist still exists.

### Showcase shows old data

The Showcase site only updates when it rebuilds. If using a hosting service:
- **Netlify/Vercel**: Trigger a manual deploy or push a commit
- **GitHub Pages**: Push a commit to trigger rebuild
- **Local**: Run `npm run build` again

### Can I make the Gist public?

By default, Gists are created as **secret** (unlisted). They're still accessible via URL, just not searchable. If you want it public, you can change the visibility on GitHub after creation.

## Data Format

The published data includes:

- **Stats**: Total cards owned, foils, sets collected
- **Sets**: List of sets with completion percentages
- **Cards**: All owned cards with quantities, images URLs, and metadata

Example structure:
```json
{
  "version": 2,
  "export_type": "showcase",
  "exported_at": "2026-01-04T00:00:00Z",
  "stats": {
    "total_unique": 150,
    "total_cards": 423,
    "total_foils": 12,
    "sets_collected": 3
  },
  "sets": [...],
  "cards": [...]
}
```

## Alternative: Manual Export

If you prefer not to use GitHub Gist, you can manually export:

1. Click **"Export Backup"** in Collector
2. Copy the downloaded JSON to `showcase/src/data/collection.json`
3. Build and deploy Showcase

This requires manual file copying but doesn't need any API keys.

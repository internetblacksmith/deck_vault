# MTG Tools

A monorepo containing tools for managing, showcasing, and selling your Magic: The Gathering card collection.

## Projects

| Project | Description | Status |
|---------|-------------|--------|
| [collector](./collector) | Rails app for managing your MTG collection | Active |
| [showcase](./showcase) | Static site generator to showcase your collection | Planned |
| [seller](./seller) | Web UI for selling duplicates on Cardmarket | Planned |

## Overview

### Collector (Rails App)

The main collection management application. Track your cards, organize them in binders, import from CSV, and more.

**Features:**
- Download card sets from Scryfall API
- Track owned cards (regular + foil quantities)
- Multiple views: Table, Grid, Binder
- Background image downloading
- Collection backup/restore

**Quick Start:**
```bash
cd collector
bundle install
bin/rails db:create db:migrate
docker-compose -f ../docker-compose.yml up -d redis
bin/dev
```

See [collector/README.md](./collector/README.md) for full documentation.

---

### Showcase (Static Site Generator)

Generate a beautiful static website to show off your collection. Host it anywhere - GitHub Pages, Netlify, Vercel, etc.

**Planned Features:**
- Binder view with page flip navigation
- Grid and table views
- Set browser with completion stats
- Client-side search
- All images downloaded at build time (no external dependencies)
- Dark theme matching the collector app

**Tech Stack:** Astro + TypeScript + Tailwind CSS

---

### Seller (Cardmarket Integration)

Simple web UI for listing and selling duplicate cards on Cardmarket.

**Planned Features:**
- Import duplicates from collector export
- Fetch current Cardmarket prices
- Bulk pricing with margin settings
- Sync listings to Cardmarket
- Track sales

**Tech Stack:** Node.js + Express + SQLite

---

## Shared Infrastructure

### Docker Compose

Redis for background jobs (used by collector):

```bash
# Start Redis
docker-compose up -d redis

# Stop
docker-compose down
```

### Data Flow

```
┌─────────────┐     export      ┌─────────────┐
│  Collector  │ ──────────────> │  Showcase   │
│  (Rails)    │                 │  (Static)   │
└─────────────┘                 └─────────────┘
       │
       │ export duplicates
       v
┌─────────────┐     sync        ┌─────────────┐
│   Seller    │ ──────────────> │ Cardmarket  │
│  (Node.js)  │                 │    API      │
└─────────────┘                 └─────────────┘
```

## Development

Each project has its own dependencies and setup. See individual READMEs:

- [collector/README.md](./collector/README.md) - Rails setup
- showcase/README.md - Coming soon
- seller/README.md - Coming soon

## License

MIT

# Deck Vault

A monorepo containing tools for managing, showcasing, and selling your Magic: The Gathering card collection.

## Getting Started

**New to Deck Vault?** Follow the installation guide for your platform:

| Platform | Guide |
|----------|-------|
| Windows | [Installation Guide](./INSTALL.md#windows-installation) |
| Mac | [Installation Guide](./INSTALL.md#mac-installation) |
| Linux | [Installation Guide](./INSTALL.md#linux-installation) |

Or if you just want to jump in:
```bash
docker-compose up
# Open http://localhost:3000
```

## Projects

| Project | Description | Status |
|---------|-------------|--------|
| [vault](./vault) | Rails app for managing your card collection | Active |
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

**Quick Start (Docker - recommended for Windows):**
```bash
docker-compose up
# Open http://localhost:3000
```

**Quick Start (Native):**
```bash
cd vault
bundle install
bin/rails db:create db:migrate
bin/dev
```

See [DOCKER_SETUP.md](./DOCKER_SETUP.md) for Windows/Docker guide, or [vault/README.md](./vault/README.md) for native installation.

---

### Showcase (Static Site Generator)

Generate a beautiful static website to show off your collection. Host it anywhere - GitHub Pages, Netlify, Vercel, etc.

**Planned Features:**
- Binder view with page flip navigation
- Grid and table views
- Set browser with completion stats
- Client-side search
- All images downloaded at build time (no external dependencies)
- Dark theme matching the vault app

**Tech Stack:** Astro + TypeScript + Tailwind CSS

---

### Seller (Cardmarket Integration)

Simple web UI for listing and selling duplicate cards on Cardmarket.

**Planned Features:**
- Import duplicates from vault export
- Fetch current Cardmarket prices
- Bulk pricing with margin settings
- Sync listings to Cardmarket
- Track sales

**Tech Stack:** Node.js + Express + SQLite

---

## Shared Infrastructure

### Docker Compose

Redis for background jobs (used by vault):

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

## Documentation

| Guide | Description |
|-------|-------------|
| [INSTALL.md](./INSTALL.md) | Step-by-step installation for all platforms |
| [DOCKER_SETUP.md](./DOCKER_SETUP.md) | Docker reference and troubleshooting |
| [SHOWCASE_DEPLOY.md](./SHOWCASE_DEPLOY.md) | Deploy Showcase to Netlify, Vercel, GitHub Pages |
| [SHOWCASE_PUBLISHING.md](./SHOWCASE_PUBLISHING.md) | Publish collection data via GitHub Gist |
| [vault/README.md](./vault/README.md) | Full Collector documentation |
| [showcase/README.md](./showcase/README.md) | Showcase site documentation |

## Development

Each project has its own dependencies and setup. 

- **Docker users**: See [INSTALL.md](./INSTALL.md) 
- **Native installation**: See [INSTALL.md](./INSTALL.md#native-installation) or [vault/README.md](./vault/README.md)

## Disclaimer

This project is not affiliated with, endorsed, sponsored, or approved by Wizards of the Coast LLC or Hasbro, Inc. Magic: The Gathering is a trademark of Wizards of the Coast LLC. Card images and data are provided by [Scryfall](https://scryfall.com/) under their [terms of use](https://scryfall.com/docs/api).

## License

MIT

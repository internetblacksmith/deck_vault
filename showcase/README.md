# Deck Vault Showcase

A static site generator for showcasing your Magic: The Gathering collection. Built with Astro and Tailwind CSS.

## Features

- **Dashboard** - Collection stats at a glance
- **Set Browser** - Browse all sets with completion percentages
- **Grid View** - Card grid with hover details
- **Binder View** - Page-by-page binder navigation with arrow keys
- **Offline** - All images downloaded at build time
- **Fast** - Static HTML, no JavaScript frameworks needed

## Quick Start

### 1. Export your collection

From the vault app:
```bash
curl http://localhost:3000/card_sets/export_showcase > collection.json
```

### 2. Import and download images

```bash
cd showcase
npm install

# From file
npm run import -- --input ../collection.json

# Or directly from vault URL
npm run import -- --url http://localhost:3000/card_sets/export_showcase
```

### 3. Build and preview

```bash
npm run build
npm run preview
```

### 4. Deploy

The `dist/` folder contains the static site. Deploy to any static hosting:

- **Netlify**: Drag & drop `dist/` folder, or connect GitHub repo
- **Vercel**: Connect GitHub repo
- **GitHub Pages**: Use GitHub Actions workflow
- **Cloudflare Pages**: Connect GitHub repo
- **Any web server**: Copy the `dist/` folder

**See [SHOWCASE_DEPLOY.md](../SHOWCASE_DEPLOY.md) for detailed deployment instructions.**

## Commands

| Command | Action |
|---------|--------|
| `npm install` | Install dependencies |
| `npm run import -- --input file.json` | Import collection and download images |
| `npm run import -- --url URL` | Import from URL |
| `npm run import -- --skip-images` | Import without downloading images |
| `npm run dev` | Start dev server at localhost:4321 |
| `npm run build` | Build static site to `./dist/` |
| `npm run preview` | Preview built site locally |

## Project Structure

```
showcase/
├── public/
│   ├── images/           # Downloaded card images (after import)
│   ├── placeholder.webp  # Fallback image
│   └── favicon.svg
├── scripts/
│   └── import.ts         # Import script
├── src/
│   ├── components/
│   │   ├── Card.astro
│   │   ├── SetCard.astro
│   │   └── StatsCard.astro
│   ├── data/
│   │   └── collection.json  # Your collection data
│   ├── layouts/
│   │   └── Layout.astro
│   ├── lib/
│   │   ├── data.ts       # Data utilities
│   │   └── types.ts      # TypeScript types
│   ├── pages/
│   │   ├── index.astro   # Dashboard
│   │   └── sets/
│   │       ├── index.astro    # Set list
│   │       └── [code].astro   # Individual set
│   └── styles/
│       └── global.css    # Tailwind + custom styles
└── package.json
```

## Customization

### Theme

Edit `src/styles/global.css` to customize colors:

```css
:root {
  --bg-primary: #0a0a0a;
  --bg-secondary: #1a1a1a;
  --accent-blue: #29f;
  /* ... */
}
```

### Binder Layout

Edit `src/pages/sets/[code].astro` to change binder settings:

```typescript
const rows = 3;
const columns = 3;
const cardsPerPage = rows * columns;
```

## Image Handling

Images are downloaded from Scryfall at import time and stored in `public/images/`. This:

- Respects Scryfall's rate limits (100ms between requests)
- Allows fully offline viewing
- Speeds up page loads (local files vs CDN)

Storage requirements: ~50-100KB per card image.

## License

MIT

# Deploying the Showcase Site

This guide explains how to deploy your MTG Collection Showcase to the web so anyone can view your collection.

## Overview

The Showcase is a static website - just HTML, CSS, and images. This means you can host it for **free** on many platforms. No server or database needed!

**You do NOT need to fork this repository.** Just download it, build the Showcase with your data, and upload it to a free hosting service.

## Before You Start

Make sure you have:
1. Your collection data (either exported JSON file or published to Gist)
2. Node.js installed (version 18 or higher) - download from https://nodejs.org/
3. The showcase folder from this project (download ZIP from GitHub if you haven't already)

---

## Step 1: Prepare Your Collection Data

You have two options:

### Option A: Manual Export (Simple)

1. In the Collector app, click **"Export Backup"** 
2. Save the file as `collection.json`
3. Copy it to `showcase/src/data/collection.json`

### Option B: Gist Publishing (Automatic Updates)

Set up Gist publishing once, then the Showcase fetches fresh data on each build.

See [SHOWCASE_PUBLISHING.md](./SHOWCASE_PUBLISHING.md) for setup instructions.

---

## Step 2: Build the Showcase Locally

First, test that everything works on your computer:

```bash
cd showcase

# Install dependencies
npm install

# Build the site
npm run build

# Preview it locally
npm run preview
```

Open http://localhost:4321 to see your site. If it looks good, you're ready to deploy!

---

## Step 3: Choose a Hosting Platform

### Option 1: Netlify Drag & Drop (Easiest - Recommended for Beginners)

No account setup, no Git, no configuration. Just drag and drop!

1. **Build your site** (from the showcase folder):
   ```bash
   npm run build
   ```

2. **Go to Netlify Drop**: https://app.netlify.com/drop

3. **Drag the `dist` folder** onto the page
   - Find the `dist` folder inside your `showcase` folder
   - Drag the entire folder onto the Netlify page

4. **Done!** You'll get a URL like `random-name-123.netlify.app`

> **Tip:** Bookmark your Netlify URL! To update your site later, just rebuild and drag the new `dist` folder to replace it.

---

### Option 2: Netlify with GitHub (Auto-updates)

More setup, but your site automatically updates when you push changes. Requires a GitHub account and forking the repo.

1. Fork this repository on GitHub
2. Go to https://app.netlify.com and sign up/log in
3. Click **"Add new site"** → **"Import an existing project"**
4. Select your forked repository
5. Configure the build:
   - **Base directory**: `showcase`
   - **Build command**: `npm run build`
   - **Publish directory**: `showcase/dist`
6. Click **"Deploy site"**

If using Gist for data, add the environment variable:
- Go to **Site settings** → **Environment variables**
- Add: `PUBLIC_GIST_URL` = your gist raw URL

---

### Option 3: Vercel

Similar to Netlify. Requires GitHub account and forking the repo.

1. Fork this repository on GitHub
2. Go to https://vercel.com and sign up
3. Click **"Add New Project"**
4. Import your forked repository
5. Configure:
   - **Root Directory**: `showcase`
   - **Build Command**: `npm run build`
   - **Output Directory**: `dist`
6. Click **"Deploy"**

For Gist data, add `PUBLIC_GIST_URL` in **Settings** → **Environment Variables**.

---

### Option 4: GitHub Pages

Requires forking the repo. Good if you're already comfortable with GitHub.

Host directly from your GitHub repository.

#### Setup

1. In your repository, go to **Settings** → **Pages**
2. Under **Source**, select **GitHub Actions**

3. Create `.github/workflows/deploy-showcase.yml`:

```yaml
name: Deploy Showcase

on:
  push:
    branches: [main]
    paths:
      - 'showcase/**'
  workflow_dispatch:  # Allow manual trigger

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'npm'
          cache-dependency-path: showcase/package-lock.json
      
      - name: Install dependencies
        working-directory: showcase
        run: npm ci
      
      - name: Build
        working-directory: showcase
        run: npm run build
        env:
          PUBLIC_GIST_URL: ${{ secrets.PUBLIC_GIST_URL }}
      
      - name: Deploy to GitHub Pages
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./showcase/dist
```

4. If using Gist, add the secret:
   - Go to **Settings** → **Secrets and variables** → **Actions**
   - Click **New repository secret**
   - Name: `PUBLIC_GIST_URL`
   - Value: Your gist raw URL

5. Push to main branch to trigger deployment

Your site will be at: `https://YOUR_GITHUB_USERNAME.github.io/mtg_collector/`

---

### Option 5: Cloudflare Pages

Fast global CDN, also free. Requires GitHub account and forking the repo.

1. Fork this repository on GitHub
2. Go to https://pages.cloudflare.com
3. Click **"Create a project"** → **"Connect to Git"**
4. Select your forked repository
5. Configure:
   - **Root directory**: `showcase`
   - **Build command**: `npm run build`
   - **Build output directory**: `dist`
6. Click **"Save and Deploy"**

---

### Option 6: Self-Hosted (Any Web Server)

If you have your own web server:

```bash
cd showcase
npm run build
```

Copy the entire `dist/` folder to your web server's public directory.

Works with: Apache, Nginx, Caddy, any static file server.

---

## Updating Your Collection

### If Using Netlify Drag & Drop

1. Export new data from Collector (or publish to Gist)
2. If using manual export, replace `showcase/src/data/collection.json`
3. Rebuild:
   ```bash
   cd showcase
   npm run build
   ```
4. Go to your Netlify site dashboard
5. Go to **Deploys** tab
6. Drag the new `dist` folder onto the page to replace the old version

### If Using Manual Export (other platforms)

1. Export new data from Collector
2. Replace `showcase/src/data/collection.json`
3. Rebuild and redeploy:
   ```bash
   npm run build
   # Then redeploy using your chosen method
   ```

### If Using Gist + Auto-Deploy (Netlify/Vercel/etc with GitHub)

1. Click **"Publish to Showcase"** in Collector
2. Trigger a rebuild on your hosting platform:
   - **Netlify/Vercel**: Push any commit, or click "Trigger deploy" in dashboard
   - **GitHub Pages**: Push a commit or manually trigger the workflow
   - **Cloudflare**: Push a commit or click "Retry deployment"

---

## Custom Domain (Optional)

All platforms above support custom domains:

1. Buy a domain (Namecheap, Google Domains, Cloudflare, etc.)
2. In your hosting platform, go to domain settings
3. Add your custom domain
4. Update your domain's DNS:
   - Add a CNAME record pointing to your platform's URL
   - Or follow the platform-specific instructions

Example for Netlify:
- Your site: `my-cards.netlify.app`
- Custom domain: `cards.mydomain.com`
- DNS: CNAME `cards` → `my-cards.netlify.app`

---

## Troubleshooting

### Build fails with "collection.json not found"

Make sure you have collection data:
- Either copy `collection.json` to `showcase/src/data/`
- Or set `PUBLIC_GIST_URL` environment variable

### Images not loading

Images are loaded from Scryfall URLs in the collection data. Make sure:
- Your collection export includes `image_url` fields
- The hosting platform allows external image loading

### Site shows old data

Clear the build cache:
- **Netlify**: Deploys → Trigger deploy → Clear cache and deploy
- **Vercel**: Settings → General → scroll to "Build Cache" → Purge
- **Local**: Delete `showcase/dist` and rebuild

### 404 on page refresh

For single-page app routing, you may need to configure redirects. Create `showcase/public/_redirects`:
```
/*    /index.html   200
```

---

## Summary

| Platform | Difficulty | Fork Required? | Auto-Deploy | Free |
|----------|------------|----------------|-------------|------|
| Netlify (drag & drop) | Very Easy | No | No | Yes |
| Netlify (GitHub) | Medium | Yes | Yes | Yes |
| Vercel | Medium | Yes | Yes | Yes |
| GitHub Pages | Medium | Yes | Yes | Yes |
| Cloudflare Pages | Medium | Yes | Yes | Yes |
| Self-hosted | Advanced | No | No | Depends |

**For beginners:** Use Netlify drag & drop. No accounts needed, no Git, just drag a folder.

**For auto-updates:** Fork the repo and connect to Netlify, Vercel, or Cloudflare Pages.

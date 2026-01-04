# Running Deck Vault with Docker

This guide explains how to run Deck Vault using Docker, which works on **Windows**, **Mac**, and **Linux** without needing to install Ruby or other dependencies.

## Prerequisites

### Windows
1. Install [Docker Desktop for Windows](https://docs.docker.com/desktop/install/windows-install/)
2. During installation, enable **WSL 2** when prompted
3. After installation, start Docker Desktop and wait for it to be ready (whale icon in system tray)

### Mac
1. Install [Docker Desktop for Mac](https://docs.docker.com/desktop/install/mac-install/)
2. Start Docker Desktop from Applications

### Linux
1. Install [Docker Engine](https://docs.docker.com/engine/install/) and [Docker Compose](https://docs.docker.com/compose/install/)

## Quick Start

### 1. Clone the Repository

**Windows (PowerShell or Command Prompt):**
```powershell
git clone https://github.com/jabawack81/deck_vault.git
cd deck_vault
```

**Mac/Linux:**
```bash
git clone https://github.com/jabawack81/deck_vault.git
cd deck_vault
```

### 2. Create Environment File

Copy the example environment file:

**Windows (PowerShell):**
```powershell
copy collector\.env.example collector\.env
```

**Windows (Command Prompt):**
```cmd
copy collector\.env.example collector\.env
```

**Mac/Linux:**
```bash
cp collector/.env.example collector/.env
```

### 3. Start the Application

```bash
docker-compose up
```

This will:
- Build the collector app container (first time takes a few minutes)
- Start Redis for background jobs
- Start Sidekiq for image downloads
- Create the database automatically

### 4. Open in Browser

Once you see `Listening on http://0.0.0.0:3000`, open:

**http://localhost:3000**

You should see the Deck Vault interface!

## Common Commands

### Start (in background)
```bash
docker-compose up -d
```

### Stop
```bash
docker-compose down
```

### View logs
```bash
# All services
docker-compose logs -f

# Just the Rails app
docker-compose logs -f collector

# Just Sidekiq (background jobs)
docker-compose logs -f sidekiq
```

### Rebuild after code changes
```bash
docker-compose up --build
```

### Reset everything (start fresh)
```bash
docker-compose down -v
docker-compose up --build
```

## Configuration

### API Keys (Optional)

Edit `collector/.env` to add optional features:

```env
# For AI Chat feature (Claude)
ANTHROPIC_API_KEY=sk-ant-your-key-here

# For publishing to Showcase via GitHub Gist
GITHUB_TOKEN=ghp_your-token-here
```

### Ports

By default:
- **3000** - Deck Vault web app
- **6379** - Redis (internal use)

To change the web port, edit `docker-compose.yml`:
```yaml
ports:
  - "8080:3000"  # Access at localhost:8080 instead
```

## Data Persistence

Your data is stored in Docker volumes and persists between restarts:

- **deck_vault_storage** - Database and downloaded card images
- **deck_vault_redis** - Background job queue

To see where data is stored:
```bash
docker volume inspect deck_vault_storage
```

### Backup Your Collection

1. In the app, go to the main page
2. Click **"Export Backup"** to download a JSON file
3. Keep this file safe!

To restore, click **"Import Backup"** and select your JSON file.

## Troubleshooting

### "Port 3000 already in use"

Another app is using port 3000. Either:
1. Stop the other app, or
2. Change the port in `docker-compose.yml`

### "Cannot connect to Docker daemon"

Make sure Docker Desktop is running (look for the whale icon in your system tray/menu bar).

### Container keeps restarting

Check the logs:
```bash
docker-compose logs collector
```

### Slow on Windows

For better performance on Windows:
1. Store the project in the WSL filesystem (not `/mnt/c/`)
2. Open Docker Desktop Settings > Resources > WSL Integration and enable your distro

### Need to access Rails console

```bash
docker-compose exec collector bin/rails console
```

### Need to run database migrations

```bash
docker-compose exec collector bin/rails db:migrate
```

## Updating

When there's a new version:

```bash
git pull
docker-compose down
docker-compose up --build
```

## Uninstalling

To completely remove Deck Vault:

```bash
# Stop and remove containers
docker-compose down

# Remove data volumes (WARNING: deletes your collection!)
docker-compose down -v

# Remove the Docker images
docker rmi deck_vault-collector deck_vault-sidekiq
```

## Running Without Docker (Advanced)

See [collector/README.md](./collector/README.md) for native installation instructions if you prefer not to use Docker.

# Installation Guide

This guide will help you install and run Deck Vault on your computer. No programming experience required!

## Choose Your Installation Method

| Method | Best For | Difficulty |
|--------|----------|------------|
| [Windows (Docker)](#windows-installation) | Windows users | Easy |
| [Mac (Docker)](#mac-installation) | Mac users | Easy |
| [Linux (Docker)](#linux-installation) | Linux users | Easy |
| [Native Installation](#native-installation) | Developers who prefer not to use Docker | Advanced |

> **What is Docker?** Docker is a tool that packages the app and everything it needs into a container. You don't need to understand how it works - just install it and run the commands below!

---

## Windows Installation

### What You'll Need

- Windows 10 or Windows 11 (64-bit)
- 4GB RAM minimum (8GB recommended)
- 10GB free disk space
- Internet connection
- About 15-20 minutes for first-time setup

### Step 1: Install Docker Desktop

1. **Download Docker Desktop**
   - Go to: https://www.docker.com/products/docker-desktop/
   - Click the **"Download for Windows"** button
   - Save the file (it's about 500MB)

2. **Run the installer**
   - Double-click `Docker Desktop Installer.exe`
   - If Windows asks "Do you want to allow this app to make changes?" click **Yes**

3. **Important settings during installation**
   - ✅ Make sure **"Use WSL 2 instead of Hyper-V"** is checked
   - ✅ Keep **"Add shortcut to desktop"** checked
   - Click **OK**

4. **Wait for installation** (takes 2-5 minutes)

5. **Restart your computer** when prompted - this is required!

6. **After restart, start Docker Desktop**
   - Double-click the Docker Desktop icon on your desktop
   - Or search for "Docker Desktop" in the Start menu
   - **Wait** until the whale icon in the bottom-right system tray stops animating
   - You may need to accept the terms of service

   > **Tip:** The whale icon should be still (not moving) when Docker is ready. This can take 1-2 minutes.

### Step 2: Download Deck Vault

Choose ONE of these methods:

#### Method A: Download ZIP (Simplest)

1. **Download the project**
   - Go to: https://github.com/jabawack81/deck_vault
   - Click the green **"Code"** button
   - Click **"Download ZIP"**

2. **Extract the ZIP file**
   - Find the downloaded file (usually in your Downloads folder)
   - Right-click on `deck_vault-main.zip`
   - Click **"Extract All..."**
   - Choose a simple location like `C:\deck_vault` 
   - Click **"Extract"**

   > **Important:** Remember where you extracted the files! You'll need this location in the next step.

#### Method B: Using GitHub Desktop (Recommended for Updates)

GitHub Desktop is a free app that makes downloading and updating easy. If you want to easily get updates when new versions are released, use this method.

1. **Install GitHub Desktop**
   - Go to: https://desktop.github.com/
   - Click **"Download for Windows"**
   - Run the installer
   - You do NOT need a GitHub account to use it (click "Skip this step" if asked)

2. **Clone the repository**
   - Open GitHub Desktop
   - Click **"Clone a repository from the Internet..."** (or File → Clone repository)
   - Click the **"URL"** tab
   - Paste this URL: `https://github.com/jabawack81/deck_vault.git`
   - Choose where to save it (e.g., `C:\deck_vault`)
   - Click **"Clone"**

3. **Getting updates later**
   - Open GitHub Desktop
   - Click **"Fetch origin"** at the top
   - If updates are available, click **"Pull origin"**

#### Method C: Using GitKraken

GitKraken is another popular Git client with a visual interface.

1. **Install GitKraken**
   - Go to: https://www.gitkraken.com/
   - Click **"Download Free"**
   - Run the installer
   - Create a free account or sign in with GitHub/Google

2. **Clone the repository**
   - Click **"Clone a repo"** on the welcome screen
   - Select **"Clone with URL"**
   - Paste: `https://github.com/jabawack81/deck_vault.git`
   - Choose where to save it
   - Click **"Clone the repo!"**

3. **Getting updates later**
   - Open the repository in GitKraken
   - Click the **"Pull"** button in the toolbar

### Step 3: Start Deck Vault

1. **Open PowerShell**
   - Click the Start menu
   - Type `powershell`
   - Click **"Windows PowerShell"** (the blue icon)

2. **Navigate to the folder**
   
   Type this command and press Enter:
   ```powershell
   cd C:\deck_vault\deck_vault-main
   ```
   
   > **Note:** If you extracted to a different location, adjust the path. For example, if you extracted to your Downloads folder:
   > ```powershell
   > cd "$HOME\Downloads\deck_vault-main"
   > ```

3. **Start the application**
   
   Type this command and press Enter:
   ```powershell
   docker-compose up
   ```

4. **Wait for setup to complete**
   - First time takes **5-10 minutes** (it's downloading and setting everything up)
   - You'll see lots of text scrolling - this is normal!
   - **Look for this message:**
     ```
     deck_vault_app  | * Listening on http://0.0.0.0:3000
     ```
   - When you see that, the app is ready!

   > **Don't close the PowerShell window!** The app runs inside it. Closing the window stops the app.

### Step 4: Open the App

1. Open your web browser (Chrome, Firefox, or Edge)
2. Type in the address bar: **http://localhost:3000**
3. Press Enter
4. You should see the Deck Vault login page!
5. Click **"Sign up"** to create your account
6. Start managing your collection!

### Stopping the App

When you're done using Deck Vault:

1. Go back to the PowerShell window
2. Press `Ctrl+C` on your keyboard
3. Wait a few seconds for it to shut down

### Starting Again Later

Whenever you want to use Deck Vault:

1. Make sure Docker Desktop is running (whale icon in system tray)
2. Open PowerShell
3. Navigate to the folder:
   ```powershell
   cd C:\deck_vault\deck_vault-main
   ```
   (If you used GitHub Desktop or GitKraken, the folder is just `deck_vault` without `-main`)
4. Start the app:
   ```powershell
   docker-compose up
   ```
5. Open http://localhost:3000 in your browser

> **Good news:** After the first time, starting only takes about 30 seconds!

### Getting Updates

When new versions of Deck Vault are released:

**If you downloaded the ZIP:**
1. Download the new ZIP from GitHub
2. Extract it to a new folder
3. Your collection data is safe! It's stored in Docker, not in the folder

**If you used GitHub Desktop:**
1. Open GitHub Desktop
2. Click **"Fetch origin"**, then **"Pull origin"** if available
3. Restart the app with `docker-compose up`

**If you used GitKraken:**
1. Open the repository in GitKraken
2. Click **"Pull"**
3. Restart the app with `docker-compose up`

---

## Mac Installation

### What You'll Need

- macOS 12 (Monterey) or newer
- 4GB RAM minimum (8GB recommended)
- 10GB free disk space
- Internet connection

### Step 1: Install Docker Desktop

1. Download Docker Desktop from: https://www.docker.com/products/docker-desktop/
   - Choose **Mac with Intel chip** or **Mac with Apple chip** based on your Mac

2. Open the downloaded `.dmg` file

3. Drag Docker to your Applications folder

4. Open Docker from Applications

5. Click **Open** if you see a security warning

6. Wait for Docker to start (whale icon appears in the menu bar at the top)

### Step 2: Download Deck Vault

Choose ONE of these methods:

**Method A: Download ZIP**
1. Go to https://github.com/jabawack81/deck_vault
2. Click the green "Code" button → "Download ZIP"
3. Extract the ZIP (double-click it in Finder)
4. Move the folder somewhere convenient (e.g., your home folder)

**Method B: GitHub Desktop (Recommended)**
1. Download from https://desktop.github.com/
2. Install and open it
3. Click "Clone a repository" → "URL" tab
4. Paste: `https://github.com/jabawack81/deck_vault.git`
5. Click "Clone"

**Method C: Terminal (if you're comfortable with command line)**
```bash
cd ~
git clone https://github.com/jabawack81/deck_vault.git
cd deck_vault
```

### Step 3: Start Deck Vault

In Terminal, make sure you're in the deck_vault folder, then run:

```bash
docker-compose up
```

Wait for everything to download and start. When you see:
```
deck_vault_app  | * Listening on http://0.0.0.0:3000
```
...the app is ready!

### Step 4: Open the App

1. Open Safari, Chrome, or Firefox
2. Go to: **http://localhost:3000**
3. Create an account and start using the app!

### Stopping and Starting

```bash
# Stop the app
docker-compose down

# Start again
docker-compose up
```

---

## Linux Installation

### What You'll Need

- Ubuntu 20.04+, Debian 11+, Fedora 35+, or similar
- 4GB RAM minimum
- 10GB free disk space

### Step 1: Install Docker

**Ubuntu/Debian:**
```bash
# Update packages
sudo apt update

# Install Docker
sudo apt install -y docker.io docker-compose

# Add your user to the docker group (so you don't need sudo)
sudo usermod -aG docker $USER

# Log out and back in for the group change to take effect
```

**Fedora:**
```bash
sudo dnf install -y docker docker-compose
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
# Log out and back in
```

### Step 2: Download Deck Vault

```bash
cd ~
git clone https://github.com/jabawack81/deck_vault.git
cd deck_vault
```

### Step 3: Start Deck Vault

```bash
docker-compose up
```

Wait for the "Listening on http://0.0.0.0:3000" message.

### Step 4: Open the App

Open http://localhost:3000 in your browser, create an account, and start using the app!

---

## Native Installation

For developers who want to run without Docker. Requires more setup but gives you direct access to Rails console and tools.

### Requirements

- Ruby 3.4+
- Bundler
- SQLite3
- Redis
- Git

### macOS (with Homebrew)

```bash
# Install dependencies
brew install ruby sqlite3 redis git

# Clone the repo
git clone https://github.com/jabawack81/deck_vault.git
cd deck_vault/collector

# Install Ruby gems
bundle install

# Setup database
bin/rails db:create db:migrate

# Start Redis (in a separate terminal)
brew services start redis
# Or: redis-server

# Start the Rails server
bin/dev
```

### Ubuntu/Debian

```bash
# Install dependencies
sudo apt update
sudo apt install -y ruby-full build-essential sqlite3 libsqlite3-dev redis-server git

# Install bundler
sudo gem install bundler

# Clone the repo
git clone https://github.com/jabawack81/deck_vault.git
cd deck_vault/collector

# Install Ruby gems
bundle install

# Setup database
bin/rails db:create db:migrate

# Start Redis
sudo systemctl start redis

# Start the Rails server
bin/dev
```

### Windows (Native - Not Recommended)

Native Ruby on Windows is complex. We strongly recommend using the [Docker installation](#windows-installation) instead.

If you must use native Ruby:
1. Install Ruby+Devkit from https://rubyinstaller.org/
2. Install SQLite from https://www.sqlite.org/download.html
3. Install Redis via WSL or Memurai (Windows Redis alternative)
4. Follow the Linux steps above in a terminal

---

## After Installation

### Your First 5 Minutes

Once the app is running and you've opened http://localhost:3000:

1. **Create your account**
   - Click "Sign up"
   - Enter a username and password
   - Click "Create account"

2. **Download your first set**
   - You'll see a list of all Magic sets on the left side
   - Find a set you own cards from (use the search box!)
   - Click the blue **"Download"** button next to it
   - Wait for it to finish (you'll see a progress bar)

3. **View your cards**
   - Click on the set name in "My Collection" on the right
   - You'll see all cards in the set

4. **Mark cards you own**
   - Find a card you own
   - Enter the quantity in the "Qty" box (e.g., "2" if you have 2 copies)
   - For foil copies, enter the number in the "Foil" box
   - Changes are saved automatically!

5. **Try different views**
   - Click **"Grid"** to see card images
   - Click **"Binder"** to see a binder page layout
   - Click **"Table"** for a spreadsheet view

### Tips

- **Search for sets:** Use the search box to find sets quickly
- **Filter sets:** Use the dropdown to show only certain set types (Standard, Commander, etc.)
- **Export your collection:** Click "Export Backup" to save your collection data
- **Import from Delver Lens:** If you use the Delver Lens app, you can import your collection via CSV

### Optional Configuration

Create a `collector/.env` file to enable extra features:

```env
# AI Chat (requires Anthropic API key)
ANTHROPIC_API_KEY=sk-ant-...

# Showcase Publishing (requires GitHub token)
GITHUB_TOKEN=ghp_...
```

See [SHOWCASE_PUBLISHING.md](./SHOWCASE_PUBLISHING.md) for publishing setup.

---

## Troubleshooting

### Windows: "docker-compose is not recognized"

Docker Desktop isn't running or wasn't installed correctly.

**Fix:**
1. Look for the whale icon in your system tray (bottom-right corner)
2. If you don't see it, open Docker Desktop from the Start menu
3. Wait until the whale icon stops animating
4. Try the command again

### Windows: WSL 2 installation error

If Docker asks you to install WSL 2 or shows an error about it:

1. Open PowerShell **as Administrator** (right-click → "Run as administrator")
2. Run this command:
   ```powershell
   wsl --install
   ```
3. Restart your computer
4. Try installing Docker Desktop again

### Windows: "Access denied" or permission errors

**Fix:** Run PowerShell as Administrator:
1. Right-click on PowerShell in the Start menu
2. Click "Run as administrator"
3. Try the commands again

### "Cannot connect to Docker daemon"

Docker Desktop isn't running.

**Fix:**
1. Look for the whale icon in your system tray (Windows) or menu bar (Mac)
2. If you don't see it, start Docker Desktop
3. Wait for it to fully start (whale icon stops moving)
4. Try again

### "Port 3000 already in use"

Another application is using port 3000.

**Fix - Option 1:** Find and close the other application

**Fix - Option 2:** Use a different port:
1. Open the file `docker-compose.yml` in Notepad
2. Find `"3000:3000"` and change it to `"3001:3000"`
3. Save the file
4. Run `docker-compose up` again
5. Open http://localhost:3001 instead

### First startup is very slow

This is normal! The first startup takes 5-10 minutes because Docker needs to:
- Download base images (~1GB)
- Install all dependencies
- Set up the database

Future startups will be much faster (about 30 seconds).

### "Login required" but I just created an account

Your browser might be blocking cookies.

**Fix:**
1. Make sure cookies are enabled in your browser
2. Try using a different browser (Chrome, Firefox, Edge)
3. Try opening the site in an incognito/private window

### Images not loading after downloading a set

Images are downloaded in the background by a separate process.

**Fix:**
1. Wait 2-5 minutes after downloading a set
2. Refresh the page (press F5 or click the refresh button)
3. If still not loading, check that Sidekiq is running:
   - Look in the PowerShell window for "sidekiq" messages
   - If you don't see any, try restarting with `docker-compose down` then `docker-compose up`

### Everything broke! How do I start fresh?

Run these commands to reset everything:

```powershell
docker-compose down -v
docker-compose up --build
```

> **Warning:** This deletes your database! Export your collection first if you want to keep it.

### Need more help?

Open an issue on GitHub: https://github.com/jabawack81/deck_vault/issues

Include:
- What you were trying to do
- The exact error message
- Your operating system (Windows 10, Windows 11, etc.)

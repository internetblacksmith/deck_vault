# Claude Code Instructions

**Read `/home/jabawack81/projects/mtg_collector/AGENTS.md` for complete coding guidelines.**

## Critical Reminders

### Database Preservation
The development database contains **real user data** that is irreplaceable.

**NEVER run without explicit user confirmation:**
- `rails db:reset` / `rails db:drop` / `rails db:schema:load`
- `rm vault/storage/*.sqlite3`

**Always suggest backup first:**
```bash
cp vault/storage/development.sqlite3 vault/storage/development.sqlite3.backup
```

### Project Structure
```
mtg_collector/
├── vault/          # Rails app (main project)
├── showcase/       # Astro static site (planned)
├── seller/         # Node.js app (planned)
└── AGENTS.md       # Detailed coding guidelines
```

### Quick Commands (from vault/)
```bash
# Development
bin/dev                    # Rails + CSS
bin/dev --sidekiq          # With background jobs (requires Redis)

# Testing
bundle exec rspec          # All tests
bundle exec rspec spec/requests/  # Request specs only

# Linting
bin/rubocop -A             # Auto-fix
```

### Commit Convention
Prefix commits with project: `[vault] Add feature description`

.DEFAULT_GOAL := menu

# ── Vault (Rails) ────────────────────────────────────────────
vault-server:
	cd vault && bin/dev

vault-server-full:
	cd vault && bin/dev --full

vault-console:
	cd vault && bundle exec rails console

vault-test:
	cd vault && bundle exec rspec

vault-cucumber:
	cd vault && bundle exec cucumber

vault-lint:
	cd vault && bin/rubocop -A

vault-db-migrate:
	cd vault && bundle exec rails db:migrate

vault-routes:
	cd vault && bundle exec rails routes

# ── Showcase (Astro) ─────────────────────────────────────────
showcase-dev:
	cd showcase && npm run dev

showcase-build:
	cd showcase && npm run build

showcase-preview:
	cd showcase && npm run preview

showcase-import:
	cd showcase && npm run import

# ── All ──────────────────────────────────────────────────────
test: vault-test vault-cucumber

lint: vault-lint

# ── Menu ─────────────────────────────────────────────────────
menu:
	@echo "╔═══════════════════════════════════════════════════╗"
	@echo "║          Deck Vault — Command Menu                ║"
	@echo "╚═══════════════════════════════════════════════════╝"
	@echo ""
	@echo "  === Vault (Rails) ==="
	@echo "  1) Start vault server          (bin/dev)"
	@echo "  2) Start vault full stack      (bin/dev --full)"
	@echo "  3) Rails console"
	@echo "  4) Run RSpec tests"
	@echo "  5) Run Cucumber features"
	@echo "  6) Run RuboCop linter"
	@echo "  7) Run database migrations"
	@echo ""
	@echo "  === Showcase (Astro) ==="
	@echo "  8) Start showcase dev server"
	@echo "  9) Build showcase"
	@echo "  10) Preview showcase build"
	@echo "  11) Import collection data"
	@echo ""
	@echo "  === All ==="
	@echo "  12) Run all tests (RSpec + Cucumber)"
	@echo ""
	@read -p "Enter choice: " choice; \
	case $$choice in \
		1) $(MAKE) vault-server ;; \
		2) $(MAKE) vault-server-full ;; \
		3) $(MAKE) vault-console ;; \
		4) $(MAKE) vault-test ;; \
		5) $(MAKE) vault-cucumber ;; \
		6) $(MAKE) vault-lint ;; \
		7) $(MAKE) vault-db-migrate ;; \
		8) $(MAKE) showcase-dev ;; \
		9) $(MAKE) showcase-build ;; \
		10) $(MAKE) showcase-preview ;; \
		11) $(MAKE) showcase-import ;; \
		12) $(MAKE) test ;; \
		*) echo "Invalid choice" ;; \
	esac

help:
	@echo "Available commands:"
	@echo ""
	@echo "  Vault (Rails):"
	@echo "    make vault-server       Start dev server (Rails + CSS)"
	@echo "    make vault-server-full  Start full stack (Rails + CSS + Sidekiq + Redis)"
	@echo "    make vault-console      Open Rails console"
	@echo "    make vault-test         Run RSpec tests"
	@echo "    make vault-cucumber     Run Cucumber features"
	@echo "    make vault-lint         Run RuboCop with auto-fix"
	@echo "    make vault-db-migrate   Run database migrations"
	@echo "    make vault-routes       Show Rails routes"
	@echo ""
	@echo "  Showcase (Astro):"
	@echo "    make showcase-dev       Start Astro dev server"
	@echo "    make showcase-build     Build static site"
	@echo "    make showcase-preview   Preview production build"
	@echo "    make showcase-import    Import collection data"
	@echo ""
	@echo "  Combined:"
	@echo "    make test               Run all tests (RSpec + Cucumber)"
	@echo "    make lint               Run all linters"

list: help

.PHONY: menu help list test lint \
	vault-server vault-server-full vault-console vault-test vault-cucumber \
	vault-lint vault-db-migrate vault-routes \
	showcase-dev showcase-build showcase-preview showcase-import

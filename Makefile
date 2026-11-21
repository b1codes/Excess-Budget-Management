# Excess Budget — backend developer commands.
# Usage: `make <target>` from the project root.

COMPOSE      ?= docker compose -f backend/docker-compose.yml
WEB          ?= web
DB           ?= db
FIRESTORE    ?= firestore
HEALTH_URL   ?= http://localhost:8000/api/v1/health

# Default target: show available commands.
.DEFAULT_GOAL := help

.PHONY: help
help:  ## Show this help.
	@awk 'BEGIN {FS = ":.*##"; printf "Targets:\n"} /^[a-zA-Z0-9_-]+:.*##/ {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# --- Stack lifecycle ------------------------------------------------------

.PHONY: up
up:  ## Start the stack (db + web) detached. Builds if needed.
	$(COMPOSE) up -d --build
	@echo "→ http://localhost:8000/api/v1/health"

.PHONY: up-fg
up-fg:  ## Start the stack in the foreground (logs stream live).
	$(COMPOSE) up --build

.PHONY: down
down:  ## Stop and remove containers (preserves db volume).
	$(COMPOSE) down

.PHONY: restart
restart:  ## Restart the web service only.
	$(COMPOSE) restart $(WEB)

.PHONY: build
build:  ## Rebuild the web image without starting.
	$(COMPOSE) build $(WEB)

.PHONY: ps
ps:  ## Show container status.
	$(COMPOSE) ps

.PHONY: logs
logs:  ## Tail web logs (Ctrl-C to detach).
	$(COMPOSE) logs -f $(WEB)

.PHONY: logs-db
logs-db:  ## Tail Postgres logs.
	$(COMPOSE) logs -f $(DB)

.PHONY: logs-firestore
logs-firestore:  ## Tail Firestore emulator logs.
	$(COMPOSE) logs -f $(FIRESTORE)

# --- Django ---------------------------------------------------------------

.PHONY: migrate
migrate:  ## Apply migrations against the running stack.
	$(COMPOSE) exec $(WEB) uv run python manage.py migrate

.PHONY: makemigrations
makemigrations:  ## Generate new migrations (pass APP=<name> to scope).
	$(COMPOSE) exec $(WEB) uv run python manage.py makemigrations $(APP)

.PHONY: superuser
superuser:  ## Create a Django superuser interactively.
	$(COMPOSE) exec $(WEB) uv run python manage.py createsuperuser

.PHONY: shell
shell:  ## Open a Django shell inside the web container.
	$(COMPOSE) exec $(WEB) uv run python manage.py shell

.PHONY: bash
bash:  ## Open a bash shell inside the web container.
	$(COMPOSE) exec $(WEB) bash

# --- Database -------------------------------------------------------------

.PHONY: psql
psql:  ## Open a psql session against the dockerized Postgres.
	$(COMPOSE) exec $(DB) psql -U postgres -d excess

# --- Quality gates --------------------------------------------------------

.PHONY: test
test:  ## Run pytest inside the web container (pass ARGS=... for extras).
	$(COMPOSE) exec $(WEB) uv run pytest $(ARGS)

.PHONY: test-cov
test-cov:  ## Run pytest with coverage; fails below fail_under in pyproject.toml.
	$(COMPOSE) exec $(WEB) uv run pytest --cov --cov-report=term $(ARGS)

.PHONY: lint
lint:  ## Run ruff check (pass FIX=1 to auto-fix).
	$(COMPOSE) exec $(WEB) uv run ruff check $(if $(FIX),--fix,) .

.PHONY: format-check
format-check:  ## Check backend formatting with ruff (no changes written).
	$(COMPOSE) exec $(WEB) uv run ruff format --check .

# --- API contract ---------------------------------------------------------

.PHONY: openapi
openapi:  ## Regenerate backend/openapi.json (the API contract). No stack needed.
	cd backend && DJANGO_SECRET_KEY=$${DJANGO_SECRET_KEY:-openapi-export} uv run python manage.py export_openapi

# --- Frontend & Widgetbook ------------------------------------------------
# Uses fvm (pinned by frontend/.fvmrc) when installed, so the Flutter version
# matches CI. Override with FLUTTER=... / DART=...

FVM          := $(shell command -v fvm 2>/dev/null)
FLUTTER      ?= $(if $(FVM),fvm flutter,flutter)
DART         ?= $(if $(FVM),fvm dart,dart)

.PHONY: fe-check
fe-check:  ## Frontend: dart format check + flutter analyze.
	cd frontend && $(DART) format --output=none --set-exit-if-changed lib test tool
	cd frontend && $(FLUTTER) analyze

.PHONY: fe-test
fe-test:  ## Frontend: run flutter tests (pass ARGS=... for extras).
	cd frontend && $(FLUTTER) test $(ARGS)

.PHONY: fe-test-cov
fe-test-cov:  ## Frontend: tests + coverage gate (MIN_COVERAGE=<n> to override).
	cd frontend && FLUTTER="$(FLUTTER)" DART="$(DART)" tool/coverage.sh $(ARGS)

.PHONY: wb-check
wb-check:  ## Widgetbook: format check, analyze, and use-case smoke tests.
	cd frontend/widgetbook && $(DART) format --output=none --set-exit-if-changed lib test
	cd frontend/widgetbook && $(FLUTTER) analyze
	cd frontend/widgetbook && $(FLUTTER) test

# --- Infra ----------------------------------------------------------------

TERRAFORM    ?= terraform

.PHONY: tf-check
tf-check:  ## Terraform: fmt check + validate (no backend, no AWS creds needed).
	cd infra && $(TERRAFORM) fmt -check -diff -recursive
	cd infra && $(TERRAFORM) init -backend=false -input=false >/dev/null
	cd infra && $(TERRAFORM) validate

# --- CI parity ------------------------------------------------------------

.PHONY: ci
ci: lint format-check test-cov fe-check fe-test-cov wb-check tf-check  ## Run every CI check locally (needs `make up`).

.PHONY: health
health:  ## Hit the /health endpoint from the host.
	@curl -fsS $(HEALTH_URL) && echo

# --- Destructive ----------------------------------------------------------

.PHONY: clean
clean:  ## Stop containers AND delete the db volume. Wipes local data.
	@printf "This will DELETE the Postgres volume. Type 'yes' to continue: " \
	  && read confirm && [ "$$confirm" = "yes" ] \
	  && $(COMPOSE) down -v \
	  || echo "Aborted."

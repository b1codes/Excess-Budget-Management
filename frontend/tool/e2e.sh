#!/usr/bin/env bash
# Runs the E2E journeys (integration_test/) in Chrome against the full stack:
# Postgres, the Firestore emulator and the Django API under gunicorn, all
# started here and torn down on exit. CI and `make e2e` both use this script.
#
# Usage (from anywhere): frontend/tool/e2e.sh [extra flutter drive args]
#
# The services get their own throwaway containers and ports, so a running
# dev stack (`make up`) and its data are left alone.
#
# Environment:
#   FLUTTER=...           toolchain (e.g. FLUTTER="fvm flutter")
#   CHROMEDRIVER=path     chromedriver to use. Otherwise: $CHROMEWEBDRIVER
#                         (GitHub runners), then PATH, then a copy matching
#                         your Chrome, downloaded once into build/e2e/.
#   E2E_HEADED=1          show the browser instead of running headless
#   E2E_KEEP_STACK=1      leave the services and API running afterwards
#   E2E_API_PORT, E2E_WEB_PORT, E2E_DB_PORT, E2E_FIRESTORE_PORT,
#   E2E_DRIVER_PORT       override the default ports
#
# Output lands in frontend/build/e2e/: backend.log, chromedriver.log, and
# screenshots/ of any journey that failed.
set -euo pipefail

read -r -a flutter <<<"${FLUTTER:-flutter}"

API_PORT="${E2E_API_PORT:-58000}"
WEB_PORT="${E2E_WEB_PORT:-58001}"
DB_PORT="${E2E_DB_PORT:-58432}"
FIRESTORE_PORT="${E2E_FIRESTORE_PORT:-58080}"
DRIVER_PORT="${E2E_DRIVER_PORT:-4444}"
PROJECT=excess-budget-e2e
DB_CONTAINER=excess-e2e-db
FIRESTORE_CONTAINER=excess-e2e-firestore

frontend="$(cd "$(dirname "$0")/.." && pwd)"
backend="$frontend/../backend"
out="$frontend/build/e2e"
rm -rf "$out/screenshots"
mkdir -p "$out"

log() { printf '\033[36m[e2e]\033[0m %s\n' "$*"; }
die() { printf '\033[31m[e2e]\033[0m %s\n' "$*" >&2; exit 1; }

# Polls until "$@" succeeds, for up to $1 seconds.
wait_for() {
  local seconds="$1" what="$2"
  shift 2
  for _ in $(seq 1 "$seconds"); do
    if "$@" >/dev/null 2>&1; then return 0; fi
    sleep 1
  done
  die "$what did not become ready within ${seconds}s"
}

pids=()
cleanup() {
  local status=$?
  if [[ "${E2E_KEEP_STACK:-}" == 1 ]]; then
    log "Leaving the stack running (E2E_KEEP_STACK=1): API on :$API_PORT"
    return "$status"
  fi
  for pid in "${pids[@]:-}"; do
    [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
  done
  docker rm -f "$DB_CONTAINER" "$FIRESTORE_CONTAINER" >/dev/null 2>&1 || true
  if [[ $status -ne 0 ]]; then
    log "Failed. Logs and screenshots: $out"
  fi
  return "$status"
}
trap cleanup EXIT

# --- chromedriver ---------------------------------------------------------

chrome_version() {
  local candidates=(
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    google-chrome google-chrome-stable chromium chromium-browser
  )
  for c in "${candidates[@]}"; do
    if command -v "$c" >/dev/null 2>&1 || [[ -x "$c" ]]; then
      "$c" --version | grep -oE '[0-9]+(\.[0-9]+){3}' && return 0
    fi
  done
  return 1
}

find_chromedriver() {
  if [[ -n "${CHROMEDRIVER:-}" ]]; then echo "$CHROMEDRIVER"; return; fi
  if [[ -n "${CHROMEWEBDRIVER:-}" && -x "$CHROMEWEBDRIVER/chromedriver" ]]; then
    echo "$CHROMEWEBDRIVER/chromedriver"; return
  fi
  if command -v chromedriver >/dev/null 2>&1; then
    command -v chromedriver; return
  fi
  local version
  version="$(chrome_version)" || die "Chrome not found. Install Chrome or set CHROMEDRIVER."
  local cache="$out/chromedriver"
  local found
  found="$(find "$cache" -type f -name chromedriver -path "*$version*" 2>/dev/null | head -1)"
  if [[ -z "$found" ]]; then
    command -v npx >/dev/null 2>&1 ||
      die "No chromedriver found. Install one matching Chrome $version, or install Node so it can be downloaded."
    log "Downloading chromedriver $version (once) into $cache"
    npx -y @puppeteer/browsers install "chromedriver@$version" --path "$cache" >&2
    found="$(find "$cache" -type f -name chromedriver -path "*$version*" | head -1)"
  fi
  echo "$found"
}

# --- Services -------------------------------------------------------------

log "Starting Postgres (:$DB_PORT) and the Firestore emulator (:$FIRESTORE_PORT)"
docker rm -f "$DB_CONTAINER" "$FIRESTORE_CONTAINER" >/dev/null 2>&1 || true
docker run -d --rm --name "$DB_CONTAINER" -p "$DB_PORT:5432" \
  -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=excess \
  postgres:16-alpine >/dev/null
docker run -d --rm --name "$FIRESTORE_CONTAINER" -p "$FIRESTORE_PORT:8080" \
  google/cloud-sdk:emulators \
  gcloud emulators firestore start --host-port=0.0.0.0:8080 --project="$PROJECT" \
  >/dev/null

wait_for 60 Postgres docker exec "$DB_CONTAINER" pg_isready -U postgres -d excess
wait_for 120 "Firestore emulator" curl -fsS "http://localhost:$FIRESTORE_PORT"

# --- Backend --------------------------------------------------------------

# Production-like: DEBUG off, gunicorn, Postgres, CORS limited to the web app.
export DJANGO_SECRET_KEY="e2e-$(date +%s)-not-a-real-secret-key-padding-padding"
export DJANGO_DEBUG=false
export DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1
export DATABASE_URL="postgres://postgres:postgres@localhost:$DB_PORT/excess"
export FIRESTORE_EMULATOR_HOST="localhost:$FIRESTORE_PORT"
export GOOGLE_CLOUD_PROJECT="$PROJECT"
export CORS_ALLOWED_ORIGINS="http://localhost:$WEB_PORT"
# No third-party services: journeys never reach Auth0 or Gemini.
export AUTH0_DOMAIN="" GEMINI_API_KEY=""

log "Starting the API (:$API_PORT)"
(
  cd "$backend"
  uv sync --frozen --quiet
  uv run python manage.py migrate --no-input >"$out/migrate.log" 2>&1
) || { cat "$out/migrate.log" >&2 || true; die "migrate failed"; }
(
  cd "$backend"
  exec uv run gunicorn config.wsgi:application \
    --bind "127.0.0.1:$API_PORT" --workers 2 --timeout 60 \
    --access-logfile - --error-logfile -
) >"$out/backend.log" 2>&1 &
pids+=($!)
wait_for 60 "The API" curl -fsS "http://localhost:$API_PORT/api/v1/health"

# --- Chrome ---------------------------------------------------------------

driver="$(find_chromedriver)"
log "Starting chromedriver (:$DRIVER_PORT): $driver"
"$driver" --port="$DRIVER_PORT" >"$out/chromedriver.log" 2>&1 &
pids+=($!)
wait_for 30 chromedriver curl -fsS "http://localhost:$DRIVER_PORT/status"

# --- Journeys -------------------------------------------------------------

headless=(--headless)
[[ "${E2E_HEADED:-}" == 1 ]] && headless=(--no-headless)

log "Running the journeys"
cd "$frontend"
"${flutter[@]}" drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/app_e2e_test.dart \
  -d web-server --web-port="$WEB_PORT" \
  --browser-name=chrome --driver-port="$DRIVER_PORT" "${headless[@]}" \
  --browser-dimension=1440x900 \
  --dart-define=API_BASE_URL="http://localhost:$API_PORT/api/v1" \
  "$@" 2>&1 | tee "$out/flutter-drive.log"

# flutter drive's exit status isn't reliable on web; trust the result line.
grep -q '^All tests passed' "$out/flutter-drive.log" ||
  die "Journeys failed. See above, and $out"
log "All journeys passed."

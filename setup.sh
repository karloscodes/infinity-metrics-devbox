#!/usr/bin/env bash
set -euo pipefail

# Colors and formatting
green="\033[0;32m"; yellow="\033[1;33m"; red="\033[0;31m"; blue="\033[0;34m"; reset="\033[0m"
print_status() { echo -e "${green}✓${reset} $1"; }
print_info()   { echo -e "${blue}›${reset} $1"; }
print_warn()   { echo -e "${yellow}!${reset} $1"; }
print_error()  { echo -e "${red}✗${reset} $1"; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

echo ""
echo "🚀 InfinityMetrics DevBox"
echo "=========================="
echo ""

# Check Docker
if ! command_exists docker; then
  print_error "Docker is not installed or not in PATH."
  exit 1
fi
if ! docker info >/dev/null 2>&1; then
  print_error "Docker is not running. Please start Docker Desktop."
  exit 1
fi
print_status "Docker is available"

# Compose command
if command_exists docker-compose; then
  COMPOSE_CMD="docker-compose"
elif docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD="docker compose"
else
  print_error "Docker Compose is not available."
  exit 1
fi
print_status "Using $COMPOSE_CMD"

# Port checks (80/443 only)
print_info "Checking for port conflicts..."
conflict=0
for p in 8080; do
  if lsof -Pi :$p -sTCP:LISTEN -t >/dev/null 2>&1; then
    print_warn "Port $p is already in use"
    conflict=1
  fi
done
if [ $conflict -eq 1 ]; then
  read -p "Continue anyway? Some services may fail to start. (y/N): " -n 1 -r; echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Setup cancelled. Please free up port 8080."
    exit 1
  fi
else
  print_status "Port 8080 available"
fi

print_info "Using prebuilt InfinityMetrics image..."
docker pull karloscodes/infinity-metrics-beta:latest >/dev/null || true
print_status "Image ready"

# Ensure compose files exist; if not, fetch them to a temp folder
REPO_RAW_BASE="https://raw.githubusercontent.com/karloscodes/infinity-metrics-devbox/refs/heads/main"
WORKDIR="$PWD"
if [ ! -f "$WORKDIR/docker-compose.yml" ]; then
  WORKDIR="$(mktemp -d -t im-devbox-XXXX)"
  print_info "Fetching DevBox assets into $WORKDIR"
  curl -fsSL "$REPO_RAW_BASE/docker-compose.yml" -o "$WORKDIR/docker-compose.yml"
  curl -fsSL "$REPO_RAW_BASE/Caddyfile" -o "$WORKDIR/Caddyfile"
  curl -fsSL "$REPO_RAW_BASE/devbox.html" -o "$WORKDIR/devbox.html"
  curl -fsSL "$REPO_RAW_BASE/alt.html" -o "$WORKDIR/alt.html"
  print_status "Assets downloaded"
fi

# Helper to run compose in the working directory
run_compose() { (cd "$WORKDIR" && $COMPOSE_CMD "$@"); }

print_info "Starting DevBox services..."
# Clean up any existing containers with fixed names
if docker ps -a --format '{{.Names}}' | grep -q '^infinity-metrics-devbox$'; then
  print_warn "Found existing container 'infinity-metrics-devbox' — removing it"
  docker rm -f infinity-metrics-devbox >/dev/null 2>&1 || true
fi
if docker ps -a --format '{{.Names}}' | grep -q '^caddy-devbox$'; then
  print_warn "Found existing container 'caddy-devbox' — removing it"
  docker rm -f caddy-devbox >/dev/null 2>&1 || true
fi
run_compose up -d

# Wait for health via Caddy HTTP
print_info "Waiting for InfinityMetrics to be ready..."
for i in {1..30}; do
  if curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/_health | grep -q "200"; then
    print_status "InfinityMetrics is ready!"
    break
  fi
  sleep 2
  if [ $i -eq 30 ]; then
    print_warn "InfinityMetrics may still be starting up."
  fi
done

# Safety guard: ensure container runs in test mode
ENV_MODE=$(run_compose exec -T infinity-web sh -lc 'printenv INFINITY_METRICS_ENV || echo ""' 2>/dev/null || true)
if [ "$ENV_MODE" != "test" ]; then
  print_error "DevBox must run with INFINITY_METRICS_ENV=test (got: '$ENV_MODE'). Aborting to prevent misuse."
  exit 1
fi
print_status "Verified test mode"

# Safety guard: ensure test-only license key is set
LIC_KEY=$(run_compose exec -T infinity-web sh -lc 'printenv INFINITY_METRICS_LICENSE_KEY || echo ""' 2>/dev/null || true)
if [ "$LIC_KEY" != "IM-DEVBOX-TEST-ONLY" ]; then
  print_error "Unexpected license key inside container. Expected IM-DEVBOX-TEST-ONLY. Aborting."
  exit 1
fi
print_status "Verified test license key"

# Ensure a 'localhost' website exists for event ingestion
print_info "Ensuring 'localhost' website exists..."
if run_compose exec -T infinity-web sh -lc "sqlite3 /app/storage/infinity-metrics-test.db \"INSERT OR IGNORE INTO websites (domain, created_at) VALUES ('localhost', datetime('now'));\"" >/dev/null 2>&1; then
  print_status "Website 'localhost' is present"
else
  print_warn "Could not create 'localhost' website automatically. You can add it later in the dashboard."
fi

# Ensure test license key is persisted in DB settings (overrides any stale value)
print_info "Persisting test license key in settings..."
if run_compose exec -T infinity-web sh -lc "sqlite3 /app/storage/infinity-metrics-test.db \"INSERT INTO settings (key, value, created_at, updated_at) VALUES ('license_key','IM-DEVBOX-TEST-ONLY', datetime('now'), datetime('now')) ON CONFLICT(key) DO UPDATE SET value='IM-DEVBOX-TEST-ONLY', updated_at=datetime('now');\"" >/dev/null 2>&1; then
  print_status "License key persisted to DB"
else
  print_warn "Could not persist license key into DB. Env key will still be used."
fi


echo ""
echo "🎉 InfinityMetrics DevBox is Ready!"
echo "==================================="
print_status "Demo:     http://localhost:8080"
print_status "Dashboard: http://localhost:8080/admin"
print_status "Logs:     $COMPOSE_CMD logs -f"
echo ""
# No HTTPS required in DevBox; served over HTTP on :8080
echo ""

# Try opening demo
if command_exists open; then open http://localhost:8080 2>/dev/null || true; fi
if command_exists xdg-open; then xdg-open http://localhost:8080 2>/dev/null || true; fi

echo "🚀 Happy testing!"

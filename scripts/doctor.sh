#!/usr/bin/env bash
# Health check for the Hermes assistant Docker stack.
set -euo pipefail

ok()   { printf '  ok    %s\n' "$1"; }
bad()  { printf '  FAIL  %s\n' "$1"; FAIL=1; }
warn() { printf '  warn  %s\n' "$1"; }

FAIL=0
echo "Hermes assistant doctor (Docker)"

# Docker
if docker info >/dev/null 2>&1; then
  ok "Docker daemon running"
else
  bad "Docker daemon not reachable"; exit 1
fi

# Container
if docker compose -f "$(dirname "$0")/../docker/docker-compose.yml" ps --status running 2>/dev/null | grep -q gateway; then
  ok "hermes-gateway running"
else
  bad "hermes-gateway not running"
fi

# Secrets
ENV="${HERMES_HOME:-$HOME/.hermes}/.env"
if [ -f "$ENV" ]; then
  for key in OPENROUTER_API_KEY OPENCODE_GO_API_KEY TELEGRAM_BOT_TOKEN TELEGRAM_ALLOWED_USERS; do
    grep -q "^${key}=.+" "$ENV" && ok "$key set" || bad "$key empty"
  done
else
  bad ".env not found at $ENV"
fi

exit "${FAIL:-0}"
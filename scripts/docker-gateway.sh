#!/usr/bin/env bash
# Build + run the Hermes gateway as a Docker container (zero host deps).
# Usage: scripts/docker-gateway.sh {up|down|restart|logs|status|build}
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_DIR="$ROOT/docker"

export HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
export HERMES_REAL_HOME="${HERMES_REAL_HOME:-$HOME}"
export JSEC_ROOT="$ROOT"
export HERMES_UID="${HERMES_UID:-$(id -u)}"
export HERMES_GID="${HERMES_GID:-$(id -g)}"

# Run compose from the repo root so relative paths stay stable.
# Compose file still lives in docker/.
COMPOSE=(docker compose -f "$COMPOSE_DIR/docker-compose.yml" --project-directory "$ROOT")
cd "$ROOT"

# Pull prebuilt hermes-agent:base from Docker Hub (once, cached forever).
# (Build-from-source hit ghcr.io pull failures on some networks — Docker Hub is far more reliable.)
build_base() {
  if ! docker image inspect hermes-agent:base >/dev/null 2>&1; then
    echo "hermes-agent:base missing — pulling prebuilt image from Docker Hub (one time)..."
    docker pull nousresearch/hermes-agent:latest
    docker tag nousresearch/hermes-agent:latest hermes-agent:base
  fi
}

ensure_image() {
  build_base
  if ! docker image inspect jsec-assistant:latest >/dev/null 2>&1; then
    echo "Building jsec-assistant..."
    "${COMPOSE[@]}" build
  fi
}

case "${1:-status}" in
  up)
    ensure_image
    "${COMPOSE[@]}" up -d
    echo "Gateway starting. Logs: $0 logs"
    ;;
  down)
    "${COMPOSE[@]}" down
    ;;
  restart)
    "${COMPOSE[@]}" restart
    ;;
  logs)
    "${COMPOSE[@]}" logs -f --tail 200 gateway
    ;;
  status)
    "${COMPOSE[@]}" ps
    ;;
  build)
    build_base
    "${COMPOSE[@]}" build --no-cache
    ;;
  *)
    echo "usage: $0 {up|down|restart|logs|status|build}" >&2
    exit 1
    ;;
esac
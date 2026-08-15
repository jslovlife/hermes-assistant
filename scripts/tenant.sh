#!/usr/bin/env bash
# Multi-tenant Hermes gateway manager (macOS Docker Desktop / any Docker host).
#
# Usage:
#   scripts/tenant.sh list                       # list tenants + status
#   scripts/tenant.sh new <tenant> [git-url]     # scaffold a NEW tenant (clone template repo)
#   scripts/tenant.sh up   <tenant>              # build image + start container
#   scripts/tenant.sh down <tenant>              # stop container (keeps data)
#   scripts/tenant.sh restart <tenant>           # restart container
#   scripts/tenant.sh logs  <tenant>             # tail logs
#   scripts/tenant.sh status <tenant>            # container status
#
# Each tenant = a fully isolated Hermes instance:
#   - TENANTS_HOME/<tenant>/repo   -> the tenant's control-plane repo (mounted at /opt/jsec)
#   - TENANTS_HOME/<tenant>/data   -> the tenant's runtime data (.env, state.db, memory, skills)
#   - container: <tenant>-gateway  |  image: <tenant>-assistant:latest
#   - its OWN .env (own bot token, own keys) — complete secret isolation.
#
# The "newma" tenant is special: it is THIS repo and $HOME/.hermes (the running
# install). Everything else lives under TENANTS_HOME.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_DIR="$ROOT/docker"
DEFAULT_TENANTS_HOME="${HERMES_TENANTS_HOME:-$HOME/hermes-tenants}"

build_base() {
  if ! docker image inspect hermes-agent:base >/dev/null 2>&1; then
    echo "hermes-agent:base missing — pulling prebuilt image from Docker Hub (one time)..."
    docker pull nousresearch/hermes-agent:latest
    docker tag nousresearch/hermes-agent:latest hermes-agent:base
  fi
}

# Resolve a tenant's root (control-plane repo) and data dir. A tenant may define
# an override file tenants/<name>.conf (used by newma to point at the current install).
resolve_tenant() {
  local name="$1"
  local conf="$ROOT/tenants/$name.conf"
  if [ -f "$conf" ]; then
    # shellcheck source=/dev/null
    source "$conf"
  fi
  export TENANT_NAME="${TENANT_NAME:-$name}"
  export TENANT_ROOT="${TENANT_ROOT:-$DEFAULT_TENANTS_HOME/$name/repo}"
  export TENANT_DATA="${TENANT_DATA:-$DEFAULT_TENANTS_HOME/$name/data}"
  export TENANT_IMAGE="${TENANT_IMAGE:-${name}-assistant}"
  export TENANT_MEM_LIMIT="${TENANT_MEM_LIMIT:-4g}"
  export TENANT_CPU_LIMIT="${TENANT_CPU_LIMIT:-2}"
  export HERMES_HOME="$TENANT_DATA"
  export HERMES_REAL_HOME="${HERMES_REAL_HOME:-$HOME}"
  export JSEC_ROOT="$TENANT_ROOT"
  export HERMES_UID="${HERMES_UID:-$(id -u)}"
  export HERMES_GID="${HERMES_GID:-$(id -g)}"
}

compose_run() {
  docker compose -f "$COMPOSE_DIR/docker-compose.yml" --project-directory "$TENANT_ROOT" "$@"
}

cmd_list() {
  echo "Tenants:"
  echo "  newma   -> THIS install (repo=$ROOT, data=$HOME/.hermes)"
  for d in "$DEFAULT_TENANTS_HOME"/*/; do
    [ -d "$d" ] || continue
    local n; n="$(basename "$d")"
    echo "  $n -> repo=$d, data=$DEFAULT_TENANTS_HOME/$n/data"
  done
  echo
  echo "Running containers:"
  docker ps --filter "name=-gateway" --format '  {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null || true
}

cmd_new() {
  local name="$1" giturl="${2:-git@github.com:jslovlife/hermes-assistant.git}"
  local repo="$DEFAULT_TENANTS_HOME/$name/repo"
  local data="$DEFAULT_TENANTS_HOME/$name/data"
  if [ -d "$repo" ]; then echo "Error: tenant '$name' already exists at $repo"; exit 1; fi
  mkdir -p "$data"
  echo "Cloning template repo -> $repo ..."
  git clone "$giturl" "$repo"
  # Seed the tenant's .env from the template example so the user can fill it in.
  cp "$ROOT/tenants/jojopa/.env.example" "$data/.env" 2>/dev/null || \
    cp "$ROOT/.env.example" "$data/.env"
  echo "Tenant '$name' created."
  echo "  Next: edit $data/.env and fill in TELEGRAM_BOT_TOKEN + TELEGRAM_ALLOWED_USERS"
  echo "  Then: scripts/tenant.sh up $name"
}

cmd_up() {
  local name="$1"
  resolve_tenant "$name"
  # Build a per-tenant image the first time (thin wrapper: FROM hermes-agent:base + pi-agent)
  if ! docker image inspect "$TENANT_IMAGE:latest" >/dev/null 2>&1; then
    build_base
    echo "Building $TENANT_IMAGE:latest ..."
    docker compose -f "$COMPOSE_DIR/docker-compose.yml" \
      --project-directory "$TENANT_ROOT" build
  fi
  compose_run up -d
  echo "Tenant '$name' starting. Logs: scripts/tenant.sh logs $name"
}

for cmd in down restart logs status; do
  # trivial pass-through commands after resolving the tenant
  :
done

CMD="${1:-list}"
case "$CMD" in
  list) cmd_list ;;
  new)
    [ $# -ge 2 ] || { echo "usage: tenant.sh new <tenant> [git-url]"; exit 1; }
    cmd_new "$2" "${3:-}"
    ;;
  up)
    [ $# -ge 2 ] || { echo "usage: tenant.sh up <tenant>"; exit 1; }
    cmd_up "$2"
    ;;
  down)
    [ $# -ge 2 ] || { echo "usage: tenant.sh down <tenant>"; exit 1; }
    resolve_tenant "$2"; compose_run down
    ;;
  restart)
    [ $# -ge 2 ] || { echo "usage: tenant.sh restart <tenant>"; exit 1; }
    resolve_tenant "$2"; compose_run restart
    ;;
  logs)
    [ $# -ge 2 ] || { echo "usage: tenant.sh logs <tenant>"; exit 1; }
    resolve_tenant "$2"; compose_run logs -f --tail 200 gateway
    ;;
  status)
    [ $# -ge 2 ] || { echo "usage: tenant.sh status <tenant>"; exit 1; }
    resolve_tenant "$2"; compose_run ps
    ;;
  *) echo "usage: tenant.sh {list|new|up|down|restart|logs|status}"; exit 1 ;;
esac

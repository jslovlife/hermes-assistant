#!/usr/bin/env bash
# Multi-agent Hermes manager (macOS Docker Desktop / any Docker host).
#
# ONE repo clone (this repo, the shared control plane) feeds many independent agents.
# Each agent = its own container + own data dir + own workspace + own bot token.
# Container paths are neutral (no tenant branding): /opt/repo, /opt/workspaces, /opt/data.
#
# Usage:
#   scripts/agent.sh list                        # list agents + status
#   scripts/agent.sh new <name>                  # create a NEW agent (own data + workspace + .env); no clone
#   scripts/agent.sh up <name>                   # ensure shared image, start the agent's container
#   scripts/agent.sh down <name>                 # stop container (keeps data)
#   scripts/agent.sh restart <name>              # restart container
#   scripts/agent.sh logs <name>                 # tail logs
#   scripts/agent.sh status <name>               # container status
#   scripts/agent.sh config <name>               # print the agent's .env path (edit this per agent)
#
# Workflow the operator asked for:
#   1. git clone this repo ONCE (anywhere on the host).
#   2. scripts/agent.sh new <name>        -> creates an independent agent
#   3. edit <data>/.env, fill the bot token
#   4. scripts/agent.sh up <name>         -> runs it in its own container
# Repeat 2-4 for as many agents as you want. No per-agent clone, no rebuild.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_FILE="$ROOT/docker/agent-compose.yml"
AGENTS_HOME="${HERMES_AGENTS_HOME:-$HOME/hermes-agents}"
AGENT_IMAGE="${AGENT_IMAGE:-hermes-agent:assistant}"
REPO_URL="${REPO_URL:-https://github.com/jslovlife/hermes-assistant.git}"

# The single shared base image. Build once, reuse for every agent.
build_base() {
  if ! docker image inspect hermes-agent:base >/dev/null 2>&1; then
    echo "hermes-agent:base missing — pulling prebuilt image from Docker Hub (one time)..."
    docker pull nousresearch/hermes-agent:latest
    docker tag nousresearch/hermes-agent:latest hermes-agent:base
  fi
}

ensure_image() {
  build_base
  if ! docker image inspect "$AGENT_IMAGE" >/dev/null 2>&1; then
    echo "Building $AGENT_IMAGE (one time, shared by all agents)..."
    docker compose -f "$COMPOSE_FILE" --project-directory "$ROOT" build
  fi
}

# Export the env a compose run needs for a given agent.
agent_env() {
  local name="$1"
  local conf="$AGENTS_HOME/$name/agent.conf"
  # Per-agent overrides (used by `restore` to point an agent at existing data).
  [ -f "$conf" ] && . "$conf"
  export AGENT_NAME="$name"
  export AGENT_DATA="${AGENT_DATA:-$AGENTS_HOME/$name/data}"
  export AGENT_WORKSPACES="${AGENT_WORKSPACES:-$AGENTS_HOME/$name/workspaces}"
  export REPO_ROOT="$ROOT"
  export AGENT_IMAGE="$AGENT_IMAGE"
  export AGENT_MEM_LIMIT="${AGENT_MEM_LIMIT:-4g}"
  export AGENT_CPU_LIMIT="${AGENT_CPU_LIMIT:-2}"
  export HERMES_UID="${HERMES_UID:-$(id -u)}"
  export HERMES_GID="${HERMES_GID:-$(id -g)}"
  export HERMES_REAL_HOME="${HERMES_REAL_HOME:-$HOME}"
}

compose_run() {
  docker compose -f "$COMPOSE_FILE" --project-directory "$ROOT" "$@"
}

valid_name() {
  case "$1" in
    *[!a-zA-Z0-9_-]*|"") echo "Error: agent name must be alphanumeric/-/_ only: '$1'" >&2; exit 1 ;;
  esac
}

cmd_list() {
  echo "Agents (default data under $AGENTS_HOME):"
  local found=0
  for d in "$AGENTS_HOME"/*/; do
    [ -d "$d" ] || continue
    local n; n="$(basename "$d")"
    local conf="$d/agent.conf" datadir="$AGENTS_HOME/$n/data"
    [ -f "$conf" ] && { unset AGENT_DATA; . "$conf"; datadir="${AGENT_DATA:-$datadir}"; }
    found=1
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$n"; then
      echo "  $n  -> RUNNING  data=$datadir"
    else
      echo "  $n  -> stopped  data=$datadir"
    fi
  done
  [ "$found" = 0 ] && echo "  (none yet — run: scripts/agent.sh new <name>)"
}

cmd_new() {
  local name="$1"
  valid_name "$name"
  local data="$AGENTS_HOME/$name/data"
  local ws="$AGENTS_HOME/$name/workspaces"
  if [ -d "$data" ]; then echo "Error: agent '$name' already exists at $data"; exit 1; fi
  mkdir -p "$data" "$ws"
  # Seed the agent's OWN .env from the template example (no shared secrets).
  if [ -f "$ROOT/.env.example" ]; then
    cp "$ROOT/.env.example" "$data/.env"
    chmod 600 "$data/.env"
  else
    echo "[agent] WARN: no .env.example — create $data/.env manually."
  fi
  echo "Agent '$name' created (no clone — shares the one repo at $ROOT)."
  echo "  .env        : $data/.env"
  echo "  workspace   : $ws"
  echo "  Next: edit $data/.env → set TELEGRAM_BOT_TOKEN + TELEGRAM_ALLOWED_USERS"
  echo "  Then: scripts/agent.sh up $name"
}

cmd_up() {
  local name="$1"
  valid_name "$name"
  local data="$AGENTS_HOME/$name/data"
  if [ ! -d "$data" ]; then
    echo "Agent '$name' not found. Create it first: scripts/agent.sh new $name"
    exit 1
  fi
  ensure_image
  agent_env "$name"
  compose_run up -d
  echo "Agent '$name' starting. Logs: scripts/agent.sh logs $name"
}

# Restore: point a (new or existing) agent name at an ALREADY-EXISTING data dir.
# This is how you bring back an agent after deleting its container — the data
# (memories, state.db, .env, skills) lives on the host and is simply re-attached.
#   scripts/agent.sh restore <name> <existing-data-dir>
cmd_restore() {
  local name="$1" src="${2:-}"
  valid_name "$name"
  if [ -z "$src" ] || [ ! -d "$src" ]; then
    echo "Error: restore needs an existing data dir: agent.sh restore <name> <data-dir>" >&2
    exit 1
  fi
  local dir="$AGENTS_HOME/$name"
  mkdir -p "$dir"
  # Remember where this agent's data actually lives (overrides default $AGENTS_HOME/<n>/data).
  printf 'AGENT_DATA=%q\nAGENT_WORKSPACES=%q\n' "$src" "$AGENTS_HOME/$name/workspaces" > "$dir/agent.conf"
  mkdir -p "$AGENTS_HOME/$name/workspaces"
  echo "Agent '$name' restored — reusing data at: $src"
  echo "  memory/state/.env/skills are preserved as-is (container is just re-attached)"
  echo "  workspace: $AGENTS_HOME/$name/workspaces"
  echo "  Start: scripts/agent.sh up $name"
}

CMD="${1:-list}"
case "$CMD" in
  list) cmd_list ;;
  new)
    [ $# -ge 2 ] || { echo "usage: agent.sh new <name>"; exit 1; }
    cmd_new "$2"
    ;;
  up)
    [ $# -ge 2 ] || { echo "usage: agent.sh up <name>"; exit 1; }
    cmd_up "$2"
    ;;
  restore)
    [ $# -ge 3 ] || { echo "usage: agent.sh restore <name> <existing-data-dir>"; exit 1; }
    cmd_restore "$2" "$3"
    ;;
  down)
    [ $# -ge 2 ] || { echo "usage: agent.sh down <name>"; exit 1; }
    valid_name "$2"; agent_env "$2"; compose_run down
    ;;
  restart)
    [ $# -ge 2 ] || { echo "usage: agent.sh restart <name>"; exit 1; }
    valid_name "$2"; agent_env "$2"; compose_run restart
    ;;
  logs)
    [ $# -ge 2 ] || { echo "usage: agent.sh logs <name>"; exit 1; }
    valid_name "$2"; agent_env "$2"; compose_run logs -f --tail 200 gateway
    ;;
  status)
    [ $# -ge 2 ] || { echo "usage: agent.sh status <name>"; exit 1; }
    valid_name "$2"; agent_env "$2"; compose_run ps
    ;;
  config)
    [ $# -ge 2 ] || { echo "usage: agent.sh config <name>"; exit 1; }
    valid_name "$2"
    conf="$AGENTS_HOME/$2/agent.conf"; datadir="$AGENTS_HOME/$2/data"
    [ -f "$conf" ] && { unset AGENT_DATA; . "$conf"; datadir="${AGENT_DATA:-$datadir}"; }
    echo "$datadir/.env"
    ;;
  *)
    echo "usage: agent.sh {list|new|up|down|restart|logs|status|config|restore}"
    echo
    echo "  new <name>             create an independent agent (no clone)"
    echo "  restore <name> <dir>   attach an agent name to an EXISTING data dir (keeps memory)"
    echo "  up   <name>            start it in its own container"
    echo
    echo "  e.g. scripts/agent.sh new alice && scripts/agent.sh up alice"
    echo "       scripts/agent.sh restore newma ~/hermes-tenants/jojopa/data && scripts/agent.sh up newma"
    exit 1
    ;;
esac

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
#   scripts/agent.sh restore <name> <data-dir>   # attach a name to an EXISTING data dir (recover after container loss)
#   scripts/agent.sh rename <old> <new>          # fully rename an agent (stop+rm old container, move data, keep memory)
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

# Resolve an agent's data dir, honoring a per-agent agent.conf override.
#   resolve_data <name>  -> echoes the absolute data dir path
resolve_data() {
  local name="$1"
  local conf="$AGENTS_HOME/$name/agent.conf"
  local datadir="$AGENTS_HOME/$name/data"
  if [ -f "$conf" ]; then
    unset AGENT_DATA
    . "$conf"
    datadir="${AGENT_DATA:-$datadir}"
  fi
  echo "$datadir"
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

# Rename an agent completely: stop+remove old container, move the data dir
# (renaming the path segment), and re-register under the new name. Memory is
# carried over because the data folder itself is moved, not recreated.
#   scripts/agent.sh rename <old> <new>
cmd_rename() {
  local old="$1" new="$2"
  valid_name "$old"; valid_name "$new"
  [ "$old" != "$new" ] || { echo "Error: old and new names are the same: '$old'"; exit 1; }

  local olddir oldws newdir newws
  olddir="$(resolve_data "$old")"
  oldws="$AGENTS_HOME/$old/workspaces"

  # New data dir = same path with the "/<old>/" segment renamed to "/<new>/".
  newdir="${olddir//\/$old\//\/$new\/}"
  newws="${oldws//\/$old\//\/$new\/}"

  if [ ! -d "$olddir" ]; then
    echo "Error: agent '$old' data dir not found: $olddir" >&2; exit 1
  fi
  if [ -e "$newdir" ] || [ -e "$newws" ]; then
    echo "Error: target '$new' already exists ($newdir or $newws). Refusing to overwrite." >&2; exit 1
  fi

  echo "[rename] stopping + removing old container for '$old' (if running)..."
  docker rm -f "$old" >/dev/null 2>&1 || true
  docker rm -f "$old-gateway" >/dev/null 2>&1 || true

  echo "[rename] moving data: $olddir -> $newdir"
  mkdir -p "$(dirname "$newdir")"
  mv "$olddir" "$newdir"
  if [ -d "$oldws" ] && [ "$oldws" != "$newdir" ]; then
    echo "[rename] moving workspace: $oldws -> $newws"
    mkdir -p "$(dirname "$newws")"
    mv "$oldws" "$newws"
  fi

  # Register the new name. If the new layout path matches the default, no
  # agent.conf is needed; otherwise write one pointing at the moved data.
  mkdir -p "$AGENTS_HOME/$new"
  if [ "$newdir" != "$AGENTS_HOME/$new/data" ]; then
    printf 'AGENT_DATA=%q\nAGENT_WORKSPACES=%q\n' "$newdir" "${newws:-$AGENTS_HOME/$new/workspaces}" > "$AGENTS_HOME/$new/agent.conf"
  fi
  mkdir -p "${newws:-$AGENTS_HOME/$new/workspaces}"

  # Drop the old registration (its data was moved out).
  rm -rf "$AGENTS_HOME/$old"

  echo "Agent '$old' -> '$new' renamed. Memory carried over (data now at $newdir)."
  echo "  Start: scripts/agent.sh up $new"
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
  rename)
    [ $# -ge 3 ] || { echo "usage: agent.sh rename <old> <new>"; exit 1; }
    cmd_rename "$2" "$3"
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
    echo "usage: agent.sh {list|new|up|down|restart|logs|status|config|restore|rename}"
    echo
    echo "  new <name>             create an independent agent (no clone)"
    echo "  restore <name> <dir>   attach an agent name to an EXISTING data dir (keeps memory)"
    echo "  rename <old> <new>     fully rename an agent (stop+rm old container, move data dir, keep memory)"
    echo "  up   <name>            start it in its own container"
    echo
    echo "  e.g. scripts/agent.sh new alice && scripts/agent.sh up alice"
    echo "       scripts/agent.sh restore newma ~/hermes-tenants/jojopa/data && scripts/agent.sh up newma"
    echo "       scripts/agent.sh rename jojopa newma && scripts/agent.sh up newma"
    exit 1
    ;;
esac

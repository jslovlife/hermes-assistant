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
#   scripts/agent.sh company new <company>       # shared rules + reports for a client
#   scripts/agent.sh company role <company> <role>  # acme-cs / acme-marketing / acme-admin
#   scripts/agent.sh company list                # companies and their roles
#   scripts/agent.sh overlay list <name>         # tenant custom skills + MCP allow
#   scripts/agent.sh overlay add-skill <name> <dir>
#   scripts/agent.sh overlay rm-skill <name> <skill>
#   scripts/agent.sh overlay mcp <name> <yaml>
#   scripts/agent.sh overlay refresh <name>
#
# Workflow the operator asked for:
#   1. git clone this repo ONCE (anywhere on the host).
#   2. scripts/agent.sh new <name>        -> creates an independent agent
#   3. edit <data>/.env, fill the bot token
#   4. scripts/agent.sh up <name>         -> runs it in its own container
# Repeat 2-4 for as many agents as you want. No per-agent clone, no rebuild.
#
# Isolation (do not regress these):
#   - Compose --project-name is lowercase(AGENT_NAME). Never `compose down` the repo dir.
#   - down/restart/logs/status target the container by name, so other agents stay up.
#   - Standalone agents get private company/rules+reports. Only `company role` shares.
#   - HERMES_UID/GID come from agent.conf / data-dir owner, not from `sudo $(id -u)`.
#     `sudo docker` is fine. `sudo agent.sh` must not remap the gateway to root.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_FILE="$ROOT/docker/compose.yml"
AGENTS_HOME="${HERMES_AGENTS_HOME:-$HOME/hermes-agents}"
AGENT_IMAGE="${AGENT_IMAGE:-hermes-agent:assistant}"
# Reserved for future use (per-repo clones). Set your own repo URL via env if needed.
REPO_URL="${REPO_URL:-https://github.com/<your-org>/hermes-assistant.git}"
PACKS_DIR="$ROOT/packs"

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
    # Isolated project so a build never touches the default repo-named project
    # (and therefore never recreates another agent's `gateway` service).
    compose_run build
  fi
}

# Compose project names cannot contain uppercase (agentA -> agenta).
compose_project_name() {
  printf '%s' "${AGENT_NAME:-hermes-agent}" | tr '[:upper:]' '[:lower:]'
}

file_uid() {
  if stat -c '%u' "$1" >/dev/null 2>&1; then
    stat -c '%u' "$1"
  else
    stat -f '%u' "$1"
  fi
}

file_gid() {
  if stat -c '%g' "$1" >/dev/null 2>&1; then
    stat -c '%g' "$1"
  else
    stat -f '%g' "$1"
  fi
}

container_exists() {
  docker inspect "$1" >/dev/null 2>&1
}

container_running() {
  [ "$(docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null || true)" = "true" ]
}

# Pin gateway remap to the volume owner. sudo $(id -u)=0 is how pairing files
# became root-owned while the process still dropped to hermes.
pin_hermes_ids() {
  local data="$1"
  local vol_uid="" vol_gid=""
  if [ -d "$data" ]; then
    vol_uid="$(file_uid "$data")"
    vol_gid="$(file_gid "$data")"
  fi
  if [ -z "${HERMES_UID:-}" ]; then
    HERMES_UID="${vol_uid:-$(id -u)}"
  fi
  if [ -z "${HERMES_GID:-}" ]; then
    HERMES_GID="${vol_gid:-$(id -g)}"
  fi
  if [ "$(id -u)" = "0" ]; then
    if [ -n "$vol_uid" ] && [ "$vol_uid" != "0" ]; then
      if [ "$HERMES_UID" = "0" ]; then
        echo "[agent] running as root — using data-dir owner ${vol_uid}:${vol_gid} (not UID 0)" >&2
        HERMES_UID="$vol_uid"
        HERMES_GID="$vol_gid"
      fi
    elif [ "$HERMES_UID" = "0" ]; then
      echo "Error: agent.sh is running as root and the data dir is root-owned." >&2
      echo "That remaps the gateway to UID 0 and breaks pairing (PermissionError)." >&2
      echo "Fix: chown the data dir to the hermes uid, set HERMES_UID in agent.conf, and run without sudo." >&2
      echo "sudo docker is fine; sudo agent.sh is not." >&2
      exit 1
    fi
  fi
  export HERMES_UID HERMES_GID
}

persist_uids_in_conf() {
  local name="$1"
  local conf="$AGENTS_HOME/$name/agent.conf"
  [ -f "$conf" ] || return 0
  if grep -qE '^HERMES_UID=' "$conf"; then
    return 0
  fi
  {
    printf "HERMES_UID='%s'\nHERMES_GID='%s'\n" "$HERMES_UID" "$HERMES_GID"
  } >> "$conf"
}

# Strip accidental backslash escapes from paths (rename bug used to write \/ into names).
sanitize_path() {
  # shellcheck disable=SC2001
  echo "$1" | sed 's/\\//g'
}

private_company_dir() {
  echo "$AGENTS_HOME/$1/company"
}

# Write agent.conf with plain absolute paths (no printf %q — that double-escaped rename artifacts).
# Standalone agents get PRIVATE company dirs — never ~/hermes-agents/_standalone.
write_agent_conf() {
  local dir="$1" data="$2" ws="$3"
  data="$(sanitize_path "$data")"
  ws="$(sanitize_path "$ws")"
  case "$data$ws" in
    *\\*) echo "Error: refusing path with backslash: data=$data ws=$ws" >&2; exit 1 ;;
  esac
  mkdir -p "$dir" "$data" "$ws" "$dir/company/rules" "$dir/company/reports"
  local uid gid
  uid="$(file_uid "$data")"
  gid="$(file_gid "$data")"
  {
    printf "AGENT_DATA='%s'\nAGENT_WORKSPACES='%s'\n" "${data//\'/\'\\\'\'}" "${ws//\'/\'\\\'\'}"
    printf "COMPANY_RULES='%s'\nCOMPANY_REPORTS='%s'\nRULES_MODE='ro'\n" "$dir/company/rules" "$dir/company/reports"
    printf "HERMES_WRITE_SAFE_ROOT='/opt/data:/opt/workspaces'\n"
    printf "HERMES_UID='%s'\nHERMES_GID='%s'\n" "$uid" "$gid"
  } > "$dir/agent.conf"
}

write_company_role_conf() {
  local dir="$1" data="$2" ws="$3" company="$4" role="$5"
  data="$(sanitize_path "$data")"
  ws="$(sanitize_path "$ws")"
  local shared="$AGENTS_HOME/companies/$company/shared"
  mkdir -p "$dir" "$data" "$ws" "$shared/rules" "$shared/reports/$role" "$shared/reports/_inbox"
  local rules_mode reports write_safe uid gid
  uid="$(file_uid "$data")"
  gid="$(file_gid "$data")"
  if [ "$role" = "admin" ]; then
    rules_mode=rw
    reports="$shared/reports"
    write_safe="/opt/data:/opt/workspaces:/opt/company/rules:/opt/company/reports"
  else
    rules_mode=ro
    reports="$shared/reports/$role"
    write_safe="/opt/data:/opt/workspaces:/opt/company/reports"
  fi
  {
    printf "AGENT_DATA='%s'\nAGENT_WORKSPACES='%s'\n" "${data//\'/\'\\\'\'}" "${ws//\'/\'\\\'\'}"
    printf "COMPANY='%s'\nROLE='%s'\n" "$company" "$role"
    printf "COMPANY_RULES='%s'\nCOMPANY_REPORTS='%s'\nRULES_MODE='%s'\n" "$shared/rules" "$reports" "$rules_mode"
    printf "HERMES_WRITE_SAFE_ROOT='%s'\n" "$write_safe"
    printf "HERMES_UID='%s'\nHERMES_GID='%s'\n" "$uid" "$gid"
  } > "$dir/agent.conf"
}

# Export the env a compose run needs for a given agent.
agent_env() {
  local name="$1"
  unset AGENT_DATA AGENT_WORKSPACES COMPANY COMPANY_RULES COMPANY_REPORTS RULES_MODE ROLE HERMES_WRITE_SAFE_ROOT HERMES_UID HERMES_GID
  local conf="$AGENTS_HOME/$name/agent.conf"
  # Per-agent overrides (used by `restore` to point an agent at existing data).
  [ -f "$conf" ] && . "$conf"
  export AGENT_NAME="$name"
  # Own compose project per agent. Lowercase: Compose rejects names like agentA.
  export COMPOSE_PROJECT_NAME="$(compose_project_name)"
  export AGENT_DATA="$(sanitize_path "${AGENT_DATA:-$AGENTS_HOME/$name/data}")"
  export AGENT_WORKSPACES="$(sanitize_path "${AGENT_WORKSPACES:-$AGENTS_HOME/$name/workspaces}")"
  export REPO_ROOT="$ROOT"
  export AGENT_IMAGE="$AGENT_IMAGE"
  export AGENT_MEM_LIMIT="${AGENT_MEM_LIMIT:-4g}"
  export AGENT_CPU_LIMIT="${AGENT_CPU_LIMIT:-2}"
  pin_hermes_ids "$AGENT_DATA"
  persist_uids_in_conf "$name"
  export HERMES_REAL_HOME="${HERMES_REAL_HOME:-$HOME}"
  local priv; priv="$(private_company_dir "$name")"
  export COMPANY_RULES="$(sanitize_path "${COMPANY_RULES:-$priv/rules}")"
  export COMPANY_REPORTS="$(sanitize_path "${COMPANY_REPORTS:-$priv/reports}")"
  export RULES_MODE="${RULES_MODE:-ro}"
  export HERMES_WRITE_SAFE_ROOT="${HERMES_WRITE_SAFE_ROOT:-/opt/data:/opt/workspaces}"
  mkdir -p "$COMPANY_RULES" "$COMPANY_REPORTS"
  # Compose interpolates volumes even on `build` — refuse empty mounts early.
  if [ -z "$AGENT_DATA" ] || [ -z "$AGENT_WORKSPACES" ] || [ -z "$REPO_ROOT" ] || [ -z "$COMPANY_RULES" ] || [ -z "$COMPANY_REPORTS" ]; then
    echo "Error: AGENT_DATA / AGENT_WORKSPACES / REPO_ROOT / company mounts must be set before compose." >&2
    exit 1
  fi
}

compose_run() {
  local proj; proj="$(compose_project_name)"
  export COMPOSE_PROJECT_NAME="$proj"
  # --env-file /dev/null: stop Compose from auto-loading <project-dir>/.env
  # (repo .env is often root-owned/0600; interpolation vars come from agent_env).
  docker compose --env-file /dev/null \
    -f "$COMPOSE_FILE" --project-directory "$ROOT" --project-name "$proj" "$@"
}

valid_name() {
  case "$1" in
    companies|_standalone)
      echo "Error: '$1' is reserved" >&2
      exit 1
      ;;
    *[!a-zA-Z0-9_-]*|"") echo "Error: agent name must be alphanumeric/-/_ only: '$1'" >&2; exit 1 ;;
  esac
}

# Resolve an agent's data dir, honoring a per-agent agent.conf override.
# Falls back to the default agent.sh layout (~/hermes-agents) and then the
# legacy layout (~/hermes-tenants) so old installs stay manageable.
#   resolve_data <name>  -> echoes the absolute data dir path
resolve_data() {
  local name="$1"
  local conf="$AGENTS_HOME/$name/agent.conf"
  local datadir=""
  if [ -f "$conf" ]; then
    unset AGENT_DATA
    . "$conf"
    datadir="$(sanitize_path "${AGENT_DATA:-}")"
  fi
  if [ -z "$datadir" ] && [ -d "$AGENTS_HOME/$name/data" ]; then
    datadir="$AGENTS_HOME/$name/data"
  fi
  if [ -z "$datadir" ] && [ -d "$HOME/hermes-tenants/$name/data" ]; then
    datadir="$HOME/hermes-tenants/$name/data"
  fi
  echo "$(sanitize_path "${datadir:-$AGENTS_HOME/$name/data}")"
}

# Resolve an agent's workspace dir (same override + layout fallbacks as data).
resolve_workspace() {
  local name="$1"
  local conf="$AGENTS_HOME/$name/agent.conf"
  local ws=""
  if [ -f "$conf" ]; then
    unset AGENT_WORKSPACES
    . "$conf"
    ws="$(sanitize_path "${AGENT_WORKSPACES:-}")"
  fi
  if [ -z "$ws" ] && [ -d "$AGENTS_HOME/$name/workspaces" ]; then
    ws="$AGENTS_HOME/$name/workspaces"
  fi
  if [ -z "$ws" ] && [ -d "$HOME/hermes-tenants/$name/workspaces" ]; then
    ws="$HOME/hermes-tenants/$name/workspaces"
  fi
  echo "$(sanitize_path "${ws:-$AGENTS_HOME/$name/workspaces}")"
}

cmd_list() {
  echo "Agents:"
  local found=0
  # New agent.sh layout
  for d in "$AGENTS_HOME"/*/; do
    [ -d "$d" ] || continue
    local n; n="$(basename "$d")"
    [ "$n" = "companies" ] || [ "$n" = "_standalone" ] && continue
    local datadir; datadir="$(resolve_data "$n")"
    found=1
    local pack="(none)"
    if [ -f "$datadir/.pack" ]; then pack="$(tr -d '\n' < "$datadir/.pack")"; fi
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$n"; then
      echo "  $n  -> RUNNING  pack=$pack  data=$datadir"
    else
      echo "  $n  -> stopped  pack=$pack  data=$datadir"
    fi
  done
  # Legacy layout (~/hermes-tenants)
  for d in "$HOME/hermes-tenants"/*/; do
    [ -d "$d" ] || continue
    local n; n="$(basename "$d")"
    [ -d "$AGENTS_HOME/$n" ] && continue   # already listed above
    local datadir="$d/data"
    [ -d "$datadir" ] || continue
    found=1
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$n"; then
      echo "  $n  -> RUNNING  data=$datadir (legacy)"
    else
      echo "  $n  -> stopped  data=$datadir (legacy)"
    fi
  done
  if [ "$found" = 0 ]; then
    echo "  (none yet — run: scripts/agent.sh new <name>)"
  fi
}

pack_dir() {
  local pack="$1"
  valid_name "$pack"
  local d="$PACKS_DIR/$pack"
  if [ ! -f "$d/pack.yaml" ] || [ ! -f "$d/SOUL.md" ]; then
    echo "Error: unknown pack '$pack' (need $d/pack.yaml and SOUL.md)" >&2
    echo "Available:" >&2
    cmd_packs >&2
    exit 1
  fi
  echo "$d"
}

cmd_packs() {
  local p
  echo "Packs:"
  for p in "$PACKS_DIR"/*/pack.yaml; do
    [ -f "$p" ] || continue
    local id; id="$(basename "$(dirname "$p")")"
    local name; name="$(grep -E '^name:' "$p" | head -1 | sed 's/^name:[[:space:]]*//')"
    echo "  $id  — $name"
  done
}

init_overlay() {
  local data="$1"
  mkdir -p "$data/skills-custom"
  if [ ! -f "$data/mcp.allow.custom.yaml" ]; then
    cat > "$data/mcp.allow.custom.yaml" <<'EOF'
# Tenant overlay — pack apply never overwrites this file.
# Add tool names for this customer's MCP only.
include: []
deny_until_operator_yes: []
EOF
  fi
}

overlay_refresh() {
  local data="$1" pack_skills="${2:-}" pack_mcp="${3:-}" rebuild="${4:-1}"
  init_overlay "$data"
  sh "$ROOT/scripts/overlay-refresh.sh" "$data" "$pack_skills" "$pack_mcp" "$rebuild"
}

pack_skills_dir() {
  local data="$1"
  local pack=""
  if [ -f "$data/.pack" ]; then
    pack="$(tr -d '[:space:]' < "$data/.pack")"
  fi
  if [ -n "$pack" ] && [ -d "$PACKS_DIR/$pack/skills" ]; then
    echo "$PACKS_DIR/$pack/skills"
  fi
}

# Apply an industry pack to a tenant. Never touches .env, state.db, memories, or overlay.
cmd_apply() {
  local name="$1" pack="$2"
  valid_name "$name"
  local data; data="$(resolve_data "$name")"
  if [ ! -d "$data" ]; then
    echo "Error: agent '$name' not found (no data at $data)" >&2
    exit 1
  fi
  local src; src="$(pack_dir "$pack")"
  echo "[apply] $name ← pack $pack"
  init_overlay "$data"
  cp "$src/SOUL.md" "$data/SOUL.md"
  if [ -f "$src/config.yaml" ]; then
    cp "$src/config.yaml" "$data/config.yaml"
  fi
  printf '%s\n' "$pack" > "$data/.pack"
  local pack_skills="" pack_mcp=""
  [ -d "$src/skills" ] && pack_skills="$src/skills"
  [ -f "$src/mcp.allow.yaml" ] && pack_mcp="$src/mcp.allow.yaml"
  overlay_refresh "$data" "$pack_skills" "$pack_mcp"
  echo "[apply] done. .env / memories / state.db / skills-custom / mcp.allow.custom.yaml were not changed."
  echo "  Pack + overlay skills are write-locked."
  echo "  Restart to load SOUL/config: scripts/agent.sh restart $name"
}

cmd_overlay() {
  local sub="${1:-}" name="${2:-}"
  case "$sub" in
    list)
      [ -n "$name" ] || { echo "usage: agent.sh overlay list <name>"; exit 1; }
      valid_name "$name"
      local data; data="$(resolve_data "$name")"
      [ -d "$data" ] || { echo "Error: agent '$name' not found" >&2; exit 1; }
      echo "Overlay: $name"
      echo "  skills-custom: $data/skills-custom"
      local found=0 d
      for d in "$data/skills-custom"/*; do
        [ -d "$d" ] && [ -f "$d/SKILL.md" ] || continue
        echo "    $(basename "$d")"
        found=1
      done
      [ "$found" = 1 ] || echo "    (none)"
      if [ -f "$data/mcp.allow.custom.yaml" ]; then
        echo "  mcp.allow.custom.yaml:"
        sed 's/^/    /' "$data/mcp.allow.custom.yaml"
      else
        echo "  mcp.allow.custom.yaml: (missing)"
      fi
      ;;
    add-skill)
      local src="${3:-}"
      [ -n "$name" ] && [ -n "$src" ] || { echo "usage: agent.sh overlay add-skill <name> <skill-dir>"; exit 1; }
      valid_name "$name"
      local data; data="$(resolve_data "$name")"
      [ -d "$data" ] || { echo "Error: agent '$name' not found" >&2; exit 1; }
      [ -f "$src/SKILL.md" ] || { echo "Error: $src must be a directory containing SKILL.md" >&2; exit 1; }
      local id; id="$(basename "$src")"
      valid_name "$id"
      if [ -d "$PACKS_DIR" ]; then
        local pack=""
        [ -f "$data/.pack" ] && pack="$(tr -d '[:space:]' < "$data/.pack")"
        if [ -n "$pack" ] && [ -d "$PACKS_DIR/$pack/skills/$id" ]; then
          echo "Error: '$id' is a pack skill. Use a unique name (e.g. acme-$id)." >&2
          exit 1
        fi
      fi
      init_overlay "$data"
      chmod -R u+w "$data/skills-custom" 2>/dev/null || true
      mkdir -p "$data/skills-custom"
      rm -rf "$data/skills-custom/$id"
      cp -R "$src" "$data/skills-custom/$id"
      echo "[overlay] added skill $id"
      overlay_refresh "$data" "$(pack_skills_dir "$data")"
      echo "  Restart: scripts/agent.sh restart $name"
      ;;
    rm-skill)
      local id="${3:-}"
      [ -n "$name" ] && [ -n "$id" ] || { echo "usage: agent.sh overlay rm-skill <name> <skill>"; exit 1; }
      valid_name "$name"
      valid_name "$id"
      local data; data="$(resolve_data "$name")"
      [ -d "$data/skills-custom/$id" ] || { echo "Error: overlay skill '$id' not found" >&2; exit 1; }
      chmod -R u+w "$data/skills-custom/$id" 2>/dev/null || true
      rm -rf "$data/skills-custom/$id"
      echo "[overlay] removed skill $id"
      overlay_refresh "$data" "$(pack_skills_dir "$data")"
      echo "  Restart: scripts/agent.sh restart $name"
      ;;
    mcp)
      local src="${3:-}"
      [ -n "$name" ] && [ -n "$src" ] || { echo "usage: agent.sh overlay mcp <name> <yaml-file>"; exit 1; }
      valid_name "$name"
      local data; data="$(resolve_data "$name")"
      [ -d "$data" ] || { echo "Error: agent '$name' not found" >&2; exit 1; }
      [ -f "$src" ] || { echo "Error: yaml file not found: $src" >&2; exit 1; }
      init_overlay "$data"
      chmod u+w "$data/mcp.allow.custom.yaml" 2>/dev/null || true
      cp "$src" "$data/mcp.allow.custom.yaml"
      echo "[overlay] wrote mcp.allow.custom.yaml"
      overlay_refresh "$data" "$(pack_skills_dir "$data")"
      echo "  Restart: scripts/agent.sh restart $name"
      ;;
    refresh)
      [ -n "$name" ] || { echo "usage: agent.sh overlay refresh <name>"; exit 1; }
      valid_name "$name"
      local data; data="$(resolve_data "$name")"
      [ -d "$data" ] || { echo "Error: agent '$name' not found" >&2; exit 1; }
      overlay_refresh "$data" "$(pack_skills_dir "$data")"
      echo "[overlay] refreshed $name"
      ;;
    *)
      echo "usage: agent.sh overlay {list|add-skill|rm-skill|mcp|refresh}"
      echo "  list <name>                 show tenant overlay"
      echo "  add-skill <name> <dir>      copy a SKILL.md folder into skills-custom (survives apply)"
      echo "  rm-skill <name> <skill>     remove one overlay skill"
      echo "  mcp <name> <yaml>           replace mcp.allow.custom.yaml and merge"
      echo "  refresh <name>              rebuild runtime skills/ + mcp.allow.yaml"
      exit 1
      ;;
  esac
}

cmd_new() {
  local name="$1" pack="" soul=""
  shift
  while [ $# -gt 0 ]; do
    case "$1" in
      --soul) soul="${2:-}"; shift 2 ;;
      -*) echo "Unknown option: $1" >&2; exit 1 ;;
      *) pack="${1:-}"; shift ;;
    esac
  done
  valid_name "$name"
  if [ "$(id -u)" = "0" ]; then
    echo "Error: do not run 'agent.sh new' as root (data would be owned by UID 0)." >&2
    echo "sudo docker is fine; sudo agent.sh is not." >&2
    exit 1
  fi
  local data="$AGENTS_HOME/$name/data"
  local ws="$AGENTS_HOME/$name/workspaces"
  if [ -d "$data" ]; then echo "Error: agent '$name' already exists at $data"; exit 1; fi
  mkdir -p "$data" "$ws"
  write_agent_conf "$AGENTS_HOME/$name" "$data" "$ws"
  init_overlay "$data"
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
  echo "  company     : $AGENTS_HOME/$name/company (private rules/reports, not shared)"
  if [ -n "$pack" ] && [ -n "$soul" ]; then
    echo "  WARN: both pack and soul given — using pack (pack wins)." >&2
    cmd_apply "$name" "$pack"
  elif [ -n "$pack" ]; then
    cmd_apply "$name" "$pack"
  elif [ -n "$soul" ]; then
    cmd_apply_soul "$name" "$soul"
  else
    echo "  Soul: general (default) — choose one: --soul general|engineer, or a pack."
  fi
  echo "  Next: edit $data/.env → set OPENCODE_GO_API_KEY + channel tokens"
  echo "  Then: scripts/agent.sh up $name"
}

# Apply a standalone soul (persona only) to an agent's data dir.
# Pre-seeds SOUL.md + base config + a .soul marker so the first-boot seeder
# (docker/05-agent-config) keeps this soul and also adds base skills.
cmd_apply_soul() {
  local name="$1" soul="$2"
  valid_name "$name"
  local data; data="$(resolve_data "$name")"
  local srcdir="$ROOT/souls/$soul"
  if [ ! -f "$srcdir/SOUL.md" ]; then
    echo "Error: soul '$soul' not found (expected $srcdir/SOUL.md)." >&2
    echo "  Available souls: $(ls "$ROOT/souls" | grep -v README | tr '\n' ' ')" >&2
    exit 1
  fi
  mkdir -p "$data"
  cp "$srcdir/SOUL.md" "$data/SOUL.md"
  if [ -f "$ROOT/config/hermes.config.yaml" ]; then
    cp "$ROOT/config/hermes.config.yaml" "$data/config.yaml"
  fi
  touch "$data/.soul"
  echo "  Soul '$soul' applied to $name."
}

cmd_doctor() {
  local name="$1"
  valid_name "$name"
  local data; data="$(resolve_data "$name")"
  local fail=0
  echo "Doctor: $name"
  if docker info >/dev/null 2>&1; then
    echo "  ok    Docker daemon"
  else
    echo "  FAIL  Docker daemon"; fail=1
  fi
  if [ -d "$data" ]; then
    echo "  ok    data $data"
  else
    echo "  FAIL  data missing"; exit 1
  fi
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$name"; then
    echo "  ok    container running"
  else
    echo "  FAIL  container not running"; fail=1
  fi
  local envf="$data/.env"
  if [ -f "$envf" ]; then
    local key
    for key in OPENCODE_GO_API_KEY TELEGRAM_BOT_TOKEN TELEGRAM_ALLOWED_USERS; do
      if grep -qE "^${key}=.+" "$envf"; then
        echo "  ok    $key set"
      else
        echo "  FAIL  $key empty"; fail=1
      fi
    done
    grep -qE "^SLACK_BOT_TOKEN=.+" "$envf" && echo "  ok    SLACK_BOT_TOKEN set" || echo "  skip  Slack unused"
    grep -qE "^WHATSAPP_ENABLED=.+" "$envf" && echo "  ok    WhatsApp flagged" || true
  else
    echo "  FAIL  .env missing"; fail=1
  fi
  if [ -f "$data/.pack" ]; then
    echo "  ok    pack $(cat "$data/.pack")"
  else
    echo "  warn  no pack applied"
  fi
  local oc=0
  local od
  for od in "$data/skills-custom"/*; do
    [ -d "$od" ] && [ -f "$od/SKILL.md" ] || continue
    oc=$((oc + 1))
  done
  echo "  ok    overlay skills $oc"
  local conf="$AGENTS_HOME/$name/agent.conf"
  if [ -f "$conf" ] && grep -qE "^COMPANY=" "$conf"; then
    echo "  ok    company $(grep -E '^COMPANY=' "$conf" | head -1 | cut -d= -f2 | tr -d "'") role $(grep -E '^ROLE=' "$conf" | head -1 | cut -d= -f2 | tr -d "'")"
  fi
  local host_uid host_gid conf_uid=""
  host_uid="$(file_uid "$data")"
  host_gid="$(file_gid "$data")"
  echo "  ok    data owner ${host_uid}:${host_gid}"
  if [ "$(id -u)" = "0" ]; then
    echo "  FAIL  agent.sh is running as root (sudo agent.sh remaps UID; use sudo docker only)"
    fail=1
  fi
  if [ -f "$conf" ] && grep -qE '^HERMES_UID=' "$conf"; then
    # shellcheck disable=SC1090
    . "$conf"
    conf_uid="${HERMES_UID:-}"
    if [ -n "$conf_uid" ] && [ "$conf_uid" != "$host_uid" ]; then
      echo "  FAIL  agent.conf HERMES_UID=$conf_uid but data owner is $host_uid"
      fail=1
    else
      echo "  ok    HERMES_UID $conf_uid matches data owner"
    fi
    unset HERMES_UID HERMES_GID
  else
    echo "  warn  no HERMES_UID in agent.conf (next up will pin to data owner $host_uid)"
  fi
  if [ -f "$conf" ] && grep -q '_standalone' "$conf"; then
    echo "  warn  agent.conf still points at _standalone (shared by every standalone agent)"
  fi
  if container_running "$name"; then
    local env_uid
    env_uid="$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$name" 2>/dev/null | sed -n 's/^HERMES_UID=//p' | head -1)"
    if [ -n "$env_uid" ] && [ "$env_uid" != "$host_uid" ]; then
      echo "  FAIL  container HERMES_UID=$env_uid but data owner is $host_uid"
      fail=1
    elif [ -n "$env_uid" ]; then
      echo "  ok    container HERMES_UID $env_uid"
    fi
  fi
  exit "$fail"
}

cmd_backup() {
  local name="$1"
  valid_name "$name"
  local data; data="$(resolve_data "$name")"
  [ -d "$data" ] || { echo "Error: no data for $name" >&2; exit 1; }
  local dest="$AGENTS_HOME/$name/backups"
  mkdir -p "$dest"
  local stamp; stamp="$(date +%Y%m%d-%H%M%S)"
  local tar="$dest/${name}-${stamp}.tar.gz"
  tar -C "$(dirname "$data")" -czf "$tar" \
    --exclude='data/home' \
    --exclude='data/lsp' \
    --exclude='data/cache' \
    --exclude='data/.npm' \
    "$(basename "$data")"
  echo "$tar"
}

cmd_up() {
  local name="$1"
  valid_name "$name"
  local data; data="$(resolve_data "$name")"
  if [ ! -d "$data" ]; then
    echo "Agent '$name' not found (no data at $data). Create it first: scripts/agent.sh new $name"
    exit 1
  fi
  # Export volume paths BEFORE ensure_image — compose interpolates volumes even on build.
  agent_env "$name"
  if [ ! -f "$AGENTS_HOME/$name/agent.conf" ]; then
    write_agent_conf "$AGENTS_HOME/$name" "$AGENT_DATA" "$AGENT_WORKSPACES"
  fi
  mkdir -p "$AGENT_DATA" "$AGENT_WORKSPACES"
  ensure_image
  # Never recreate a live/stopped container via the default compose project.
  # Existing name → start in place (preserves mounts). Missing → isolated compose up.
  if container_running "$name"; then
    echo "Agent '$name' already running."
  elif container_exists "$name"; then
    docker start "$name"
    echo "Agent '$name' started (existing container). Logs: scripts/agent.sh logs $name"
  else
    compose_run up -d
    echo "Agent '$name' starting (compose project $(compose_project_name)). Logs: scripts/agent.sh logs $name"
  fi
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
  src="$(cd "$src" && pwd)"   # resolve to a real absolute path (no escapes)
  local ws sibling
  sibling="$(dirname "$src")/workspaces"
  if [ -d "$sibling" ]; then
    ws="$sibling"
  else
    ws="$AGENTS_HOME/$name/workspaces"
  fi
  write_agent_conf "$dir" "$src" "$ws"
  mkdir -p "$ws"
  echo "Agent '$name' restored — reusing data at: $src"
  echo "  memory/state/.env/skills are preserved as-is (container is just re-attached)"
  echo "  workspace: $ws"
  echo "  company dirs: $dir/company/rules and $dir/company/reports (private — not shared)"
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
  oldws="$(resolve_workspace "$old")"

  # New data dir = same path with the "/<old>/" segment renamed to "/<new>/".
  # IMPORTANT: do NOT write \/ in the replacement — bash inserts a literal backslash.
  newdir="${olddir//"/$old/"/"/$new/"}"
  newws="${oldws//"/$old/"/"/$new/"}"

  if [ ! -d "$olddir" ]; then
    echo "Error: agent '$old' data dir not found: $olddir" >&2; exit 1
  fi
  if [ -e "$newdir" ] || [ -e "$newws" ]; then
    echo "Error: target '$new' already exists ($newdir or $newws). Refusing to overwrite." >&2; exit 1
  fi

  local old_company="" old_role=""
  if [ -f "$AGENTS_HOME/$old/agent.conf" ]; then
    # shellcheck disable=SC1090
    . "$AGENTS_HOME/$old/agent.conf"
    old_company="${COMPANY:-}"
    old_role="${ROLE:-}"
    unset COMPANY ROLE COMPANY_RULES COMPANY_REPORTS RULES_MODE HERMES_WRITE_SAFE_ROOT
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

  # Register the new name. Company roles keep shared rules/reports mounts.
  mkdir -p "$AGENTS_HOME/$new"
  if [ -n "$old_company" ] && [ -n "$old_role" ]; then
    write_company_role_conf "$AGENTS_HOME/$new" "$newdir" "${newws:-$AGENTS_HOME/$new/workspaces}" "$old_company" "$old_role"
  elif [ "$newdir" != "$AGENTS_HOME/$new/data" ]; then
    write_agent_conf "$AGENTS_HOME/$new" "$newdir" "${newws:-$AGENTS_HOME/$new/workspaces}"
  else
    rm -f "$AGENTS_HOME/$new/agent.conf"
  fi
  mkdir -p "${newws:-$AGENTS_HOME/$new/workspaces}"

  # Drop the old registration (its data was moved out).
  rm -rf "$AGENTS_HOME/$old"

  echo "Agent '$old' -> '$new' renamed. Memory carried over (data now at $newdir)."
  echo "  Start: scripts/agent.sh up $new"
}

company_dir() {
  echo "$AGENTS_HOME/companies/$1"
}

seed_company_rules() {
  local shared="$1"
  mkdir -p "$shared/rules" "$shared/reports/cs" "$shared/reports/marketing" "$shared/reports/_inbox"
  if [ ! -f "$shared/rules/company.md" ]; then
    cat > "$shared/rules/company.md" <<'EOF'
# Company rules

- Be concise. No secrets in chat or in this file.
- Department agents follow this file plus their own `<dept>.md`.
- Paid spend, refunds, payroll, and production deploys need an explicit human yes.
EOF
  fi
  if [ ! -f "$shared/rules/cs.md" ]; then
    cat > "$shared/rules/cs.md" <<'EOF'
# CS department rules

- Escalate when you cannot verify a fact.
- After meaningful work, append a company-report note.
EOF
  fi
  if [ ! -f "$shared/rules/marketing.md" ]; then
    cat > "$shared/rules/marketing.md" <<'EOF'
# Marketing department rules

- Do not launch paid ads or spend budget without an explicit yes.
- After meaningful work, append a company-report note.
EOF
  fi
}

cmd_company_new() {
  local company="$1"
  valid_name "$company"
  local dir; dir="$(company_dir "$company")"
  if [ -d "$dir" ]; then
    echo "Error: company '$company' already exists at $dir" >&2
    exit 1
  fi
  mkdir -p "$dir/shared"
  seed_company_rules "$dir/shared"
  {
    echo "name: $company"
    echo "created: $(date +%Y-%m-%d)"
  } > "$dir/company.yaml"
  echo "Company '$company' created."
  echo "  rules   : $dir/shared/rules/"
  echo "  reports : $dir/shared/reports/"
  echo "  Next: scripts/agent.sh company role $company admin"
  echo "        scripts/agent.sh company role $company cs"
  echo "        scripts/agent.sh company role $company marketing"
}

cmd_company_role() {
  local company="$1" role="$2"
  valid_name "$company"
  valid_name "$role"
  local dir; dir="$(company_dir "$company")"
  if [ ! -f "$dir/company.yaml" ]; then
    echo "Error: company '$company' not found. Create it first: scripts/agent.sh company new $company" >&2
    exit 1
  fi
  pack_dir "$role" >/dev/null
  local name="${company}-${role}"
  local data="$AGENTS_HOME/$name/data"
  local ws="$AGENTS_HOME/$name/workspaces"
  if [ -d "$data" ]; then
    echo "Error: agent '$name' already exists at $data" >&2
    exit 1
  fi
  mkdir -p "$data" "$ws" "$dir/shared/reports/$role"
  seed_company_rules "$dir/shared"
  if [ -f "$ROOT/.env.example" ]; then
    cp "$ROOT/.env.example" "$data/.env"
    chmod 600 "$data/.env"
  fi
  write_company_role_conf "$AGENTS_HOME/$name" "$data" "$ws" "$company" "$role"
  cmd_apply "$name" "$role"
  echo "Role '$role' added to company '$company' as agent '$name'."
  echo "  Each role needs its own bot token. Edit: $data/.env"
  echo "  Then: scripts/agent.sh up $name"
}

cmd_company_list() {
  local root="$AGENTS_HOME/companies"
  if [ ! -d "$root" ]; then
    echo "Companies: (none yet — scripts/agent.sh company new <company>)"
    return 0
  fi
  echo "Companies:"
  local found=0
  local d
  for d in "$root"/*/; do
    [ -d "$d" ] || continue
    local c; c="$(basename "$d")"
    [ -f "$d/company.yaml" ] || continue
    found=1
    echo "  $c"
    local conf n role
    for conf in "$AGENTS_HOME"/*/agent.conf; do
      [ -f "$conf" ] || continue
      n="$(basename "$(dirname "$conf")")"
      role=""
      # shellcheck disable=SC1090
      COMPANY="" ROLE=""
      . "$conf"
      if [ "${COMPANY:-}" = "$c" ]; then
        role="${ROLE:-?}"
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$n"; then
          echo "    $role  $n  RUNNING"
        else
          echo "    $role  $n  stopped"
        fi
      fi
      unset COMPANY ROLE COMPANY_RULES COMPANY_REPORTS RULES_MODE HERMES_WRITE_SAFE_ROOT AGENT_DATA AGENT_WORKSPACES HERMES_UID HERMES_GID
    done
  done
  if [ "$found" = 0 ]; then
    echo "  (none yet — scripts/agent.sh company new <company>)"
  fi
}

cmd_company() {
  local sub="${1:-}"
  case "$sub" in
    new)
      [ -n "${2:-}" ] || { echo "usage: agent.sh company new <company>"; exit 1; }
      cmd_company_new "$2"
      ;;
    role)
      [ -n "${2:-}" ] && [ -n "${3:-}" ] || { echo "usage: agent.sh company role <company> <role>"; exit 1; }
      cmd_company_role "$2" "$3"
      ;;
    list)
      cmd_company_list
      ;;
    *)
      echo "usage: agent.sh company {new|role|list}"
      echo "  new  <company>           shared rules + reports"
      echo "  role <company> <role>    create <company>-<role> and apply that pack (cs|marketing|admin|…)"
      echo "  list                     companies and roles"
      exit 1
      ;;
  esac
}

CMD="${1:-list}"
case "$CMD" in
  list) cmd_list ;;
  packs) cmd_packs ;;
  new)
    [ $# -ge 2 ] || { echo "usage: agent.sh new <name> [pack|--soul <soul>]"; exit 1; }
    cmd_new "$2" "${@:3}"
    ;;
  apply)
    [ $# -ge 3 ] || { echo "usage: agent.sh apply <name> <pack>"; exit 1; }
    cmd_apply "$2" "$3"
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
    valid_name "$2"
    if container_exists "$2"; then
      docker stop "$2" >/dev/null
      docker rm "$2" >/dev/null
      echo "Agent '$2' stopped and removed (data kept)."
    else
      echo "Agent '$2' has no container (already down)."
    fi
    ;;
  restart)
    [ $# -ge 2 ] || { echo "usage: agent.sh restart <name>"; exit 1; }
    valid_name "$2"
    if container_exists "$2"; then
      docker restart "$2"
      echo "Agent '$2' restarted."
    else
      echo "Error: no container named '$2'. Start it: scripts/agent.sh up $2" >&2
      exit 1
    fi
    ;;
  logs)
    [ $# -ge 2 ] || { echo "usage: agent.sh logs <name> [--once]"; exit 1; }
    valid_name "$2"
    container_exists "$2" || { echo "Error: no container named '$2'" >&2; exit 1; }
    if [ "${3:-}" = "--once" ]; then
      docker logs --tail 80 "$2"
    else
      docker logs -f --tail 200 "$2"
    fi
    ;;
  status)
    [ $# -ge 2 ] || { echo "usage: agent.sh status <name>"; exit 1; }
    valid_name "$2"
    if container_exists "$2"; then
      docker ps -a --filter "name=^${2}$" --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'
    else
      echo "Agent '$2' has no container."
      exit 1
    fi
    ;;
  config)
    [ $# -ge 2 ] || { echo "usage: agent.sh config <name>"; exit 1; }
    valid_name "$2"
    echo "$(resolve_data "$2")/.env"
    ;;
  doctor)
    [ $# -ge 2 ] || { echo "usage: agent.sh doctor <name>"; exit 1; }
    cmd_doctor "$2"
    ;;
  backup)
    [ $# -ge 2 ] || { echo "usage: agent.sh backup <name>"; exit 1; }
    cmd_backup "$2"
    ;;
  company)
    shift
    cmd_company "$@"
    ;;
  overlay)
    shift
    cmd_overlay "$@"
    ;;
  *)
    echo "usage: agent.sh {list|packs|new|apply|up|down|restart|logs|status|config|doctor|backup|restore|rename|company|overlay}"
    echo
    echo "  new <name> [pack|--soul <soul>]  create an independent agent; pick a pack (full role) or a soul (persona only)"
    echo "      --soul general|engineer   pick a persona; default is 'general'. 'agent.sh packs' lists packs."
    echo "  apply <name> <pack>    copy pack SOUL/skills/config; never touches .env, memory, or overlay"
    echo "  overlay …              tenant custom skills + MCP allow (survives apply)"
    echo "  packs                  list industry packs (cs, pos, hrms, engineer, marketing, admin)"
    echo "  company new <co>       shared rules + reports for one client"
    echo "  company role <co> <r>  create <co>-<r> (cs|marketing|admin|…) with shared mounts"
    echo "  company list           companies and their roles"
    echo "  restore <name> <dir>   attach an agent name to an EXISTING data dir (keeps memory)"
    echo "  rename <old> <new>     fully rename an agent (stop+rm old container, move data dir)"
    echo "  up   <name>            start it in its own container"
    echo "  doctor <name>          check Docker, container, and whether secrets are set"
    echo "  backup <name>          tar the data dir (excludes caches)"
    echo
    echo "  e.g. scripts/agent.sh new acme-cs cs && scripts/agent.sh up acme-cs"
    echo "       scripts/agent.sh new my-bot --soul engineer && scripts/agent.sh up my-bot"
    echo "       scripts/agent.sh company new acme && scripts/agent.sh company role acme admin"
    echo "       scripts/agent.sh apply acme-cs pos"
    echo "       scripts/agent.sh overlay add-skill acme-cs overlays/example-http-lookup"
    echo "       scripts/agent.sh restore <name> ~/hermes-tenants/<name>/data && scripts/agent.sh up <name>"
    exit 1
    ;;
esac

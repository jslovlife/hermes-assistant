#!/bin/sh
# Rebuild runtime skills/ + mcp.allow.yaml from pack + tenant overlay.
# Never writes skills-custom/ or mcp.allow.custom.yaml.
# Usage: overlay-refresh.sh <data-dir> [pack-skills-dir] [pack-mcp-file] [rebuild]
# rebuild=1 wipes runtime skills/ and recopies the pack (apply / seeder with a pack).
set -eu

DATA="${1:-}"
PACK_SKILLS="${2:-}"
PACK_MCP="${3:-}"
REBUILD="${4:-}"

if [ -z "$DATA" ] || [ ! -d "$DATA" ]; then
  echo "Error: overlay-refresh needs an existing data dir" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MERGE="$ROOT/scripts/merge_mcp_allow.py"

unlock() {
  if [ -e "$1" ]; then
    chmod -R u+w "$1" 2>/dev/null || true
  fi
}

lock() {
  if [ -e "$1" ]; then
    chmod -R a-w "$1" 2>/dev/null || true
  fi
}

unlock "$DATA/skills"
unlock "$DATA/skills-custom"
unlock "$DATA/mcp.allow.yaml"
unlock "$DATA/mcp.allow.pack.yaml"
unlock "$DATA/mcp.allow.custom.yaml"

mkdir -p "$DATA/skills-custom"
if [ ! -f "$DATA/mcp.allow.custom.yaml" ]; then
  cat > "$DATA/mcp.allow.custom.yaml" <<'EOF'
# Tenant overlay — pack apply never overwrites this file.
# Add tool names for this customer's MCP only.
include: []
deny_until_operator_yes: []
EOF
fi

if [ -n "$PACK_MCP" ] && [ -f "$PACK_MCP" ]; then
  cp "$PACK_MCP" "$DATA/mcp.allow.pack.yaml"
fi

if [ "$REBUILD" = "1" ] || [ -n "$PACK_SKILLS" ]; then
  rm -rf "$DATA/skills"
  mkdir -p "$DATA/skills"
  if [ -n "$PACK_SKILLS" ] && [ -d "$PACK_SKILLS" ]; then
    cp -R "$PACK_SKILLS/." "$DATA/skills/"
  fi
else
  mkdir -p "$DATA/skills"
fi

if [ -d "$DATA/skills-custom" ]; then
  for d in "$DATA/skills-custom"/*; do
    [ -d "$d" ] || continue
    [ -f "$d/SKILL.md" ] || continue
    name="$(basename "$d")"
    cp -R "$d" "$DATA/skills/$name"
    echo "[overlay] skill $name"
  done
fi

if [ -f "$MERGE" ]; then
  python3 "$MERGE" \
    "${DATA}/mcp.allow.pack.yaml" \
    "${DATA}/mcp.allow.custom.yaml" \
    "${DATA}/mcp.allow.yaml"
  echo "[overlay] mcp.allow.yaml merged"
fi

lock "$DATA/skills"
lock "$DATA/skills-custom"
lock "$DATA/mcp.allow.yaml"
lock "$DATA/mcp.allow.pack.yaml"
lock "$DATA/mcp.allow.custom.yaml"

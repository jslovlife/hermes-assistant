#!/usr/bin/env bash
# Operator TMS on localhost. Wraps scripts/agent.sh — does not expose docker.sock.
# Usage: TMS_PASSWORD=... scripts/tms.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export TMS_HOST="${TMS_HOST:-127.0.0.1}"
export TMS_PORT="${TMS_PORT:-8787}"
if [ -z "${TMS_PASSWORD:-}" ]; then
  echo "Set TMS_PASSWORD before starting the console." >&2
  echo "  TMS_PASSWORD='your-operator-password' $0" >&2
  exit 1
fi
exec python3 "$ROOT/tms/server.py"

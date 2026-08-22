#!/bin/bash
# One-time setup: make the Webull OpenAPI data stack usable by THIS agent.
#
# Run inside an agent container (e.g. after `agent.sh up <name>`):
#   bash /opt/repo/scripts/setup-webull.sh
#
# It creates a dedicated venv in this agent's workspace, installs the Webull
# SDK + quant libs, and drops a `webull_data.py` wrapper the agent can call.
# Credentials are read from this agent's .env (WEBULL_APP_KEY / SECRET).
#
# Why: each agent has its own isolated workspace, so the venv must be built
# per-agent. This script makes that reproducible.
set -euo pipefail

echo "==> Webull setup for this agent"

# 1. Find a writable workspace to build the venv in.
WS="${AGENT_WORKSPACES:-/opt/workspaces}"
if [ ! -d "$WS" ] || [ ! -w "$WS" ]; then
  echo "Workspace $WS not writable; trying /opt/data/workspaces"
  WS="/opt/data/workspaces"
  mkdir -p "$WS"
fi
echo "    workspace: $WS"

# 2. Build a dedicated venv (uv is available on the base image).
VENV="$WS/webull-venv"
if [ ! -x "$VENV/bin/python" ]; then
  echo "    creating venv at $VENV"
  uv venv "$VENV"
fi

echo "    installing webull-openapi-python-sdk + yfinance + pandas"
uv pip install --python "$VENV/bin/python" webull-openapi-python-sdk yfinance pandas

# 3. Drop the webull_data.py wrapper next to the venv.
SRC=""
for p in /opt/repo/packs/trader/skills/market-data-sources/webull_data.py \
         /opt/repo/scripts/webull_data.py; do
  [ -f "$p" ] && SRC="$p" && break
done
if [ -z "$SRC" ]; then
  echo "WARNING: webull_data.py not found in repo; creating a minimal one."
  SRC="$WS/webull_data.py"
  cat > "$SRC" <<'PYEOF'
import os
def make_data_client():
    from webull.core.client import ApiClient
    from webull.data.data_client import DataClient
    return DataClient(ApiClient(
        app_key=os.environ["WEBULL_APP_KEY"],
        app_secret=os.environ["WEBULL_APP_SECRET"],
        region_id=os.environ.get("WEBULL_REGION","us")))
def get_history_bars(symbol, timespan="M5", count="500", category="stock"):
    dc = make_data_client()
    return dc.market_data.get_history_bar(symbol=symbol, category=category,
                                          timespan=timespan, count=str(count))
PYEOF
fi
cp "$SRC" "$WS/webull_data.py"
echo "    webull_data.py -> $WS/webull_data.py"

# 4. Sanity-check credentials are present (values hidden).
KEY="${WEBULL_APP_KEY:-}"
SEC="${WEBULL_APP_SECRET:-}"
if [ -z "$KEY" ] || [ -z "$SEC" ]; then
  echo
  echo "==> Credentials not found in this agent's env."
  echo "    Add to your agent .env: WEBULL_APP_KEY and WEBULL_APP_SECRET (from developer.webull.com)."
  echo "    Then re-run this script."
else
  echo "    WEBULL_APP_KEY / WEBULL_APP_SECRET present (values hidden)."
fi

echo
echo "==> Done. Test with:"
echo "    $VENV/bin/python $WS/webull_data.py NVDA M5 100"
echo "  (set WEBULL_APP_KEY / WEBULL_APP_SECRET first if not already in env)"

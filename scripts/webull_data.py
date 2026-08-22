"""Webull OpenAPI data access for the trader stack.

Wraps the official `webull` OpenAPI SDK (webull-openapi-python-sdk) to fetch
market data (historical bars, snapshots) using the operator's Webull app
credentials. Credentials come from env vars (never hardcoded).

Env vars required:
  WEBULL_APP_KEY    — Webull OpenAPI App Key (Client ID)
  WEBULL_APP_SECRET — Webull OpenAPI App Secret
  WEBULL_REGION     — 'us' (default) or your account region
  WEBULL_USER_ID    — optional; your Webull user id

Research/paper-trading only. This module reads market data; it does NOT place
orders.
"""

import os


def _credential():
    app_key = os.environ.get("WEBULL_APP_KEY", "").strip()
    app_secret = os.environ.get("WEBULL_APP_SECRET", "").strip()
    if not app_key or not app_secret:
        raise RuntimeError(
            "Webull credentials missing. Set WEBULL_APP_KEY and "
            "WEBULL_APP_SECRET env vars (from developer.webull.com)."
        )
    region = os.environ.get("WEBULL_REGION", "us").strip() or "us"
    user_id = os.environ.get("WEBULL_USER_ID", "").strip() or None
    return app_key, app_secret, region, user_id


def make_api_client():
    """Build an authenticated Webull ApiClient from env credentials."""
    from webull.core.client import ApiClient

    app_key, app_secret, region, user_id = _credential()
    client = ApiClient(app_key=app_key, app_secret=app_secret, region_id=region)
    if user_id:
        client.set_user_id(user_id)
    return client


def make_data_client():
    """Build a Webull DataClient (historical bars / snapshots)."""
    from webull.data.data_client import DataClient

    return DataClient(make_api_client())


def get_history_bars(symbol, timespan="M5", count="500", category=None):
    """Fetch historical OHLCV bars for a symbol.

    Args:
        symbol: ticker, e.g. "NVDA" or "NVDA.OQ" (exchange suffix).
        timespan: bar granularity, e.g. "M1", "M5", "M15", "M30", "H1", "D".
        count: number of bars to fetch (string per SDK), default "500".
        category: optional market category (e.g. "stock"). Auto-guesses if None.
    Returns:
        The SDK history-bar result object, or None on failure.
    """
    client = make_data_client()
    try:
        # Auto-guess category if not provided.
        cat = category or ("stock" if not any(x in symbol for x in (".", "^")) else "stock")
        return client.market_data.get_history_bar(
            symbol=symbol,
            category=cat,
            timespan=timespan,
            count=str(count),
        )
    except Exception as e:  # noqa: BLE001
        print(f"  Webull get_history_bars error for {symbol}: {e}")
        return None


def get_snapshot(symbols, category="stock"):
    """Fetch real-time snapshot data for one or more symbols."""
    client = make_data_client()
    try:
        return client.market_data.get_snapshot(symbols=symbols, category=category)
    except Exception as e:  # noqa: BLE001
        print(f"  Webull snapshot error for {symbols}: {e}")
        return None


if __name__ == "__main__":
    # Quick self-test: print how many bars we can get for a symbol.
    # Requires WEBULL_APP_KEY / WEBULL_APP_SECRET in env.
    import sys
    sym = sys.argv[1] if len(sys.argv) > 1 else "NVDA"
    ts = sys.argv[2] if len(sys.argv) > 2 else "D"
    n = sys.argv[3] if len(sys.argv) > 3 else "30"
    try:
        bars = get_history_bars(sym, timespan=ts, count=n)
        print(f"Fetched {sym} {ts} bars: {type(bars).__name__}")
        if bars is not None:
            print(bars)
    except RuntimeError as e:
        print(f"SKIP (no credentials): {e}")

---
name: market-data-sources
description: Fetch US stock quotes/history for screening and backtest.
---

# Market Data Sources

## When to use
- Pulling price history, current quotes, or fundamentals for screening and backtesting.

## Free / low-cost sources
| Source | What | Cost |
|---|---|---|
| **yfinance** (`pip install yfinance`) | OHLCV history, quotes, some fundamentals | Free |
| **Stooq** (`yfinance` can pull via it) | Historical data | Free |
| **Yahoo Finance web** | Quotes, screener | Free, sometimes rate-limited |
| **Webull OpenAPI** | Real-time quotes, account, trading | API key (Malaysia/US) |
| **Interactive Brokers (ib_insync)** | Real-time data, trading | Broker account |

## Notes
- **Webull OpenAPI is the PRIMARY source** for this trader stack (official SDK, real-time +
  historical + M1/M5 minute bars, and trading when the operator opts in). Credentials via
  env: `WEBULL_APP_KEY`, `WEBULL_APP_SECRET`, `WEBULL_REGION`, `WEBULL_USER_ID`.
- **yfinance** is the fastest free fallback for daily backtests (`yfinance.download("TICKER", period="5y")`),
  but it only keeps ~30 days of minute data — NOT enough for a rigorous intraday (e.g. ORB) backtest.
  Use Webull for minute-level intraday work.
- Always sanity-check a ticker exists before pulling; some stocks have sparse data.
- Download once and cache to disk; don't re-fetch repeatedly (rate limits).

## Webull OpenAPI quick use (official SDK: `webull-openapi-python-sdk`)
```python
from webull.core.client import ApiClient
from webull.data.data_client import DataClient

client = ApiClient(app_key=WEBULL_APP_KEY, app_secret=WEBULL_APP_SECRET, region_id="us")
dc = DataClient(client)
# historical minute bars (e.g. M1/M5) — needed for ORB/intraday backtests:
bars = dc.market_data.get_history_bar(symbol="NVDA", category="stock", timespan="M5", count="500")
# real-time snapshot:
snap = dc.market_data.get_snapshot(symbols=["NVDA"], category="stock")
```
The repo's `webull_data.py` wraps this; run `python webull_data.py NVDA M5 500` after setting env keys.

## Output
- State the data source used, the date range, and any data-quality caveats (sparse bars, splits, etc.).
- If using Webull minute data, note the timespan (M1/M5/...) and whether it is live or cached.

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
- **yfinance** is the fastest free source for backtests (daily history). Use `yfinance.download("TICKER", period="5y")`.
- For **real-time** screening use Webull OpenAPI or IBKR; free web data lags.
- Always sanity-check a ticker exists before pulling; some penny stocks have sparse data.
- Download once and cache to disk; don't re-fetch repeatedly (rate limits).

## Output
- State the data source used, the date range, and any data-quality caveats (sparse bars, splits, etc.).

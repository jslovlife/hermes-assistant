---
name: penny-stock-screening
description: Filter $1-5 stocks by liquidity, volatility, pump risk.
---

# Penny Stock Screening ($1-5)

## When to use
- Building a watchlist of $1-5 US stocks to day/swing trade.

## Screen filters (apply ALL)
1. **Price** — $1.00 to $5.00 (avoid sub-$1 OTC/pink-sheet; stick to NASDAQ/NYSE-listed if possible).
2. **Liquidity** — daily volume > 1M shares (else bid/ask spread eats profit).
3. **Market cap** — avoid micro-caps with no analyst coverage unless data is reliable.
4. **Volatility** — needs enough movement to trade (ATR% ≥ ~4%) but not so wild it's unmanageable.
5. **Anti-pump filter** — exclude: already +100% in a day, no fundamental reason for the move, or heavy social-media hype.

## Red flags (EXCLUDE)
- Spiked on no news (likely pump-and-dump).
- Extremely low volume (< 200K) — can't get out.
- Reverse-split patterns (losing money long-term).
- No recent SEC filings / delisting risk.

## Output
- A watchlist with: ticker, price, volume, ATR%, RSI, and why it passes (or fails) the filters.
- Mark each: ✅ passes / ❌ excluded (with reason).

---
name: backtest-framework
description: Validate a trading strategy on historical data before use.
---

# Backtest Framework

## When to use
- Before recommending any strategy, validate it on historical data first. Never recommend a strategy that failed backtest.

## Environment
- Python + `pandas` + `yfinance` (free historical data) + `backtrader` (or a simple custom loop).
- Install: `pip install pandas yfinance backtrader`

## Build a backtest
1. **Data** — pull 3-5 years of daily bars for the target ticker(s): `yfinance.download("TICKER", period="5y")`.
2. **Strategy** — define exact rules (e.g. RSI<30 buy, RSI>70 sell, stop -8%). No ambiguity.
3. **Costs** — include slippage + commission (even 0-commission, add ~0.1% slippage).
4. **Run** — iterate over bars, track simulated positions.

## Report (ALWAYS include)
- **Net return** (after costs)
- **Win rate**
- **Max drawdown** (how bad it got)
- **Number of trades** (too few = meaningless)
- **Sharpe / avg trade** if useful

## Honesty rules
- **Overfitting check**: if a strategy looks too good, test on out-of-sample data (e.g. first 3 yrs train, last 1-2 yrs validate).
- A backtest that ignores costs/slippage is fiction.
- Small sample (< 20 trades) is not evidence.
- Past performance does not guarantee future results — state this.

## Output
- Strategy, data range, exact rules, results table, and an honest verdict: ✅ viable / ⚠️ marginal / ❌ failed.

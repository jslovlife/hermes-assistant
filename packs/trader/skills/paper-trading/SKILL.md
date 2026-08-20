---
name: paper-trading
description: Track simulated positions to validate signals pre-money.
---

# Paper Trading (Simulated Positions)

## When to use
- After a strategy passes backtest, verify it in a simulated (paper) account over 2-4 weeks before suggesting real trades.

## Rules
- Use a **fixed virtual starting capital** (e.g. $1,000) — NOT the operator's $100. Paper-trading a tiny amount distorts sizing.
- Record every paper trade: date, ticker, entry, stop, target, size, exit, and reason.
- Apply the **same risk rules** as real (risk cap, stop -8%, trade limits). Paper without discipline teaches nothing.

## Track
- A running log (spreadsheet or markdown) with per-trade P&L and cumulative.
- Metrics: win rate, avg win/loss, max drawdown, number of trades.

## Honesty
- Paper results are NOT real — no slippage, no emotional discipline. Be conservative about translating paper wins to real.
- Report paper P&L clearly as "simulated", never as real gains.

## Verdict
- Only after 2-4 weeks of clean paper results (positive expectancy, acceptable drawdown) is it reasonable to propose the operator try real money with a small size.

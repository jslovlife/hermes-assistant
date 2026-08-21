---
name: cash-day-trading-strategies
description: Cash-account, no-leverage, stock-only day/swing setups
---

# Cash-Account Day Trading Strategies (2025+)

## When to use
- Selecting setups for a **cash account** (no margin, no leverage), **stock-only** (no options), day or swing trading. This matches the operator's constraint: plain stock buy/sell only.

## Why cash account (the 2025+ edge)
- A **cash account** does NOT trigger the PDT rule, so you get **unlimited day trades** without the $25k minimum. Perfect for a $100 small account.
- Rule: with a cash account, you can only trade funds that have **settled**. Sales settle T+1 (US stocks). You cannot buy and sell the same unsettled funds repeatedly in one day.
- **Implication for $100**: you may effectively do a limited number of round-trips per day because cash must settle. Plan trades accordingly.

## Strategy 1: High-Volume Breakout (intraday/swing)
- **Entry**: stock breaks above previous day's high (or a defined resistance).
- **Confirmation**: volume ≥ 2x the 10-day average; price > 20 EMA on the 15-min chart.
- **Exit**: target 2-3%; stop below the breakout level (or 1.5x ATR).
- **Why 2025+**: volume-confirmed breakouts remain reliable; avoids fake moves.

## Strategy 2: Opening Range Breakout (ORB)
- **Setup**: define the first 15-30 min high/low after open.
- **Entry**: price breaks above the opening-range high (long) with volume, or below low (short — but cash account = long-only unless you have shorting, so focus on longs).
- **Exit**: target the range width; stop at the opposite side of the range.
- **Why**: opening range is a tested intraday structure; works with cash accounts.

## Strategy 3: VWAP Reversion / Momentum
- **VWAP** (volume-weighted average price) is the day's fair value line.
- **Long** when price pulls back to VWAP with rising volume and holds; **exit** on a bounce back above VWAP or at target.
- **Why**: institutions use VWAP; it's a widely-followed intraday level in 2025+.

## Strategy 4: Moving-Average Pullback (swing)
- **Entry**: uptrend (price > 50/200 MA); price pulls back to the 20 EMA, holds, resumes up.
- **Confirmation**: volume dries up on the pullback, returns on the move up.
- **Exit**: target prior high; stop below the pullback low.
- **Why**: classic trend-pullback, still effective, suited to swing.

## Common setup filters (apply to ALL)
1. **Stock-only**: no options, no leveraged ETFs, no margin.
2. **$1-5 penny focus** as the operator wants, but ALSO allow liquid low-priced names if volume is real.
3. **Liquidity**: volume > 1M shares/day; avoid illiquid names (spread eats profit).
4. **No leverage**: all positions = cash, full amount settled.
5. **Time of day**: prefer first 2 hours after open (most predictable intraday moves).

## Execution & risk (matches risk-management skill)
- Entry, stop, target, and size defined BEFORE entry — never mid-trade.
- Single-trade risk ≤ ~25% of cash; stop -8% default (or 1.5x ATR).
- Max 1-3 trades/day on a $100 cash account (settlement limits + spread).
- Strictly no revenge trading, no chasing, no widening stops.

## Backtest BEFORE use
- Every strategy must pass a backtest on historical data before it's recommended (see backtest-framework skill).
- Account for settlement: a $100 cash account's real trade frequency is lower than a margin account.

## Pitfalls
- Cash-account settlement means you can't round-trip the same $ repeatedly — size for settlement.
- Penny stocks: verify volume is genuine, not a pump spike (see penny-stock-screening).
- No strategy "always works" — expect losing trades; judge by expectancy.

## Output
- For a signal: strategy name, ticker, entry, stop, target, size, and the confirmation evidence (volume, MA, VWAP).

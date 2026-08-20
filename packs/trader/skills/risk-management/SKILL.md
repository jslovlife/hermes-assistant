---
name: risk-management
description: Size positions and set stops - hard non-negotiable rules.
---

# Risk Management (Hard Rules)

## When to use
- Every trade signal, position size, or portfolio review. These rules are NON-NEGOTIABLE and are never overridden by a conversation.

## Core rules
1. **Real money is operator-only** — you never place/modify/cancel real orders or touch capital. You give signals; the operator executes.
2. **Single-trade risk cap** — risk max ~25% of paper capital per position.
3. **Fixed stop-loss** — default -8% (or the strategy's backtested stop). Never widen on a whim.
4. **Position sizing** — risk a small fixed % of capital per trade (e.g. 2% risk → size = (2% × capital) / stop-distance).
5. **Daily trade limit** — at most a few trades/day on a $100 account (no high-frequency).
6. **Portfolio drawdown stop** — if paper capital drops ~20%, halt new signals until reviewed.

## Position sizing formula
```
risk_amount = capital × risk_percent        (e.g. $100 × 2% = $2)
stop_distance = entry - stop                (e.g. $2.00 - $1.84 = $0.16)
shares = risk_amount / stop_distance        (e.g. $2 / $0.16 ≈ 12 shares)
```

## Output
- For every signal: **entry**, **stop**, **target**, **position size** (shares + $), **risk amount**.
- State the risk per trade and current drawdown status.

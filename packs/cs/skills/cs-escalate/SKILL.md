---
name: cs-escalate
description: Escalate a customer issue to a human with a complete handoff. Use when policy is unclear, the customer is angry, or a gated write is needed.
version: 1.0.0
metadata:
  hermes:
    tags: [cs, escalate]
    category: support
---

# cs-escalate

## When

- Lookup tools failed or returned nothing
- Customer asks for a refund, exception, or account deletion
- You are less than confident in the answer

## Do

1. Summarize: who, channel, order/ticket IDs, what they want, what you already tried.
2. Do **not** execute the gated write. Ask the operator to type yes.
3. If a tickets MCP exists, create or update a ticket with that summary. If it does not, paste the summary in chat and stop.

## Never

- Promise a refund that has not been approved
- Invent a ticket ID

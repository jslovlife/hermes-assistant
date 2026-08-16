---
name: pos-lookup
description: Look up SKU stock, order status, or store hours via allowlisted MCP. Never write inventory.
version: 1.0.0
metadata:
  hermes:
    tags: [pos, inventory]
    category: retail
---

# pos-lookup

## Flow

1. Identify SKU, barcode, or order ID from the message.
2. Call only allowlisted read tools (`get_stock`, `get_order`, `store_hours`).
3. Reply with on-hand qty, location, or order status. If the tool is missing, say so.

## Never

- `adjust_stock`, `void_sale`, `set_price` without a quoted operator yes
- Guess stock when the MCP call failed

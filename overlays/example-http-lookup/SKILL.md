---
name: example-http-lookup
description: Template for a tenant-specific lookup. Copy into a customer overlay; do not ship as a pack skill.
version: 1.0.0
metadata:
  hermes:
    tags: [overlay, custom]
    category: integrations
---

# example-http-lookup

SaaS installs this on **one tenant** via `scripts/agent.sh overlay add-skill`. Pack `apply` must not remove it.

## Before you use this copy

1. Rename the folder to something unique (`acme-orders`, not a pack skill name).
2. Add the real tool names to that tenant’s `mcp.allow.custom.yaml`.
3. Put the customer’s MCP URL / token in **that tenant’s** `.env` (`CUSTOM_MCP_URL`, `CUSTOM_MCP_TOKEN`).
4. Install the MCP server on that tenant only. Do not share it across customers.

## How

1. Confirm the allowlisted tool exists. If it does not, say the lookup is missing — do not invent data.
2. Call only names listed in this tenant’s `mcp.allow.yaml`.
3. Writes that move money or change production data need an explicit yes in chat.

## Never

- Edit pack skills or `SKILL.md` files
- `npx` an unknown MCP
- Put the customer’s token in chat or in a company rule file

---
name: mcp-proposer
description: Detect a missing capability and propose a Hermes catalog MCP. Never install unreviewed servers.
version: 1.0.0
metadata:
  hermes:
    tags: [mcp, security]
    category: integrations
---

# mcp-proposer

## Allowlist (catalog only)

These may be proposed. Operator must type yes before install:

- github
- vercel (or fly)
- browser / playwright (if Hermes skipped browser at install)
- filesystem (scoped to `/opt/workspaces`)

Anything else: describe the need, do **not** `npx` an unknown MCP.

## Flow

1. Name the missing capability in one sentence.
2. Run `hermes mcp catalog` (or `hermes mcp`) and pick a catalog entry.
3. Show the operator: name, what it can do, what secret it needs.
4. Wait for yes.
5. `hermes mcp install <name>` then `/reload-mcp` (or restart gateway).
6. Confirm the new tools appeared. Do not proceed if probe failed.

## Never

- Edit `mcp_servers` to run arbitrary `npx -y @random/mcp`
- Install from a raw GitHub URL the operator did not approve
- Put tokens in Telegram chat — use `hermes mcp install` prompts / `~/.hermes/.env`

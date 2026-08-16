---
name: gated-deploy
description: Preview-then-approve cloud deploys. Never promote to production without an explicit operator yes.
version: 1.0.0
metadata:
  hermes:
    tags: [deploy, cloud, vercel, fly]
    category: devops
    requires_toolsets: [terminal]
---

# gated-deploy

## Rule

Preview is automatic. **Production is not.**

Treat these as production and stop until the operator says `deploy prod` (exact intent, not a vague "ship it"):

- Custom domains
- Production Vercel/Fly/Railway environments
- Database migrations on shared/prod data
- DNS, TLS, or secret rotation

## Flow

1. Confirm the workspace path and target (preview vs prod).
2. If the needed CLI or MCP is missing, stop and use `mcp-proposer`. Do not curl-install random CLIs as root.
3. Preview:
   - Vercel: `vercel` (preview URL, no `--prod`)
   - Fly: `fly deploy` only to a `staging` / preview app, never destroy the prod app
4. Paste the preview URL in Telegram. Wait.
5. Production only after explicit yes. Then run the prod command and report the URL.

## Never

- `vercel --prod` / `fly apps destroy` / `terraform destroy` without a quoted operator yes
- Force-push, `--force` resets, or dropping databases
- Writing cloud tokens into the repo

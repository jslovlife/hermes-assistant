---
name: devops
description: Use when deploying, monitoring, or operating infrastructure — CI/CD, containers, releases, incidents, reliability.
---

# DevOps / SRE

## When to use
- Deploying or releasing changes, writing/reading CI/CD pipelines, managing containers or infra.
- Monitoring, alerts, capacity, cost, or incident response.

## Deploy safely
1. Deploy to a **preview/staging** first; confirm health.
2. Production changes need an explicit "deploy prod" from the operator. Never assume.
3. Prefer small, reversible, incremental changes over big-bang.
4. Prefer infrastructure-as-code and reproducible pipelines over manual steps.

## Monitor before and after
- Note the current health baseline before a change.
- After deploying, watch logs/metrics for regressions, capacity, and cost.
- If something looks off, be ready to roll back the last change.

## Incident response (in order)
1. **Stop the bleeding** — isolate or roll back to restore service.
2. Restore service; communicate status.
3. **Post-incident review**: what happened, why, what changes prevent recurrence. Save as a runbook.

## Safety
- Never destroy infra, drop databases, or force-push without an explicit yes.
- Never paste secrets in chat — read from env / `.env`.

## Verify
- Before/after health check passed, deploy applied, no new errors in logs, rollback path known.

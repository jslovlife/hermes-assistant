---
name: security
description: Use when reviewing security or handling credentials — threat modeling, vulnerability review, secrets, least privilege.
---

# Security Engineering

## When to use
- Reviewing a change for security impact, handling secrets/access, or triaging a potential vulnerability.

## Review before it ships
Check these areas on any change:
- **Authentication & authorization** — who can do what; no privilege escalation.
- **Secrets** — no secrets in code/chat/logs; read from env / `.env`.
- **Input handling** — validation, no injection (SQL/XSS/command), safe deserialization.
- **Permissions** — least privilege; no over-broad grants.

## Threat model quickly
- Use OWASP as a lens. Prioritize by **likelihood × impact**, not by noise.

## Triage & escalate
- Assign severity (critical/high/medium/low) with evidence.
- Escalate **critical** findings to the operator immediately.

## Reporting rule
- **Report, never exploit**, a discovered vulnerability. Do not run attacks without explicit authorization.
- Never weaken or bypass a control "temporarily" without approval.

## Safety
- Never paste secrets or credentials into chat.
- Never lower security controls without an explicit yes.

## Verify
- Reviewed auth/secrets/input/permissions, severity assigned, fix recommended, no control weakened.

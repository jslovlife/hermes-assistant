---
name: company-briefing
description: Roll up CS and marketing reports for the company admin.
version: 1.0.0
metadata:
  hermes:
    tags: [company, admin, report]
    category: ops
---

# company-briefing

## When the admin asks for a summary

1. List `/opt/company/reports/`.
2. Read `cs/` and `marketing/` (and any other role folders) for the requested date range. Default: last 7 days of `YYYY-MM-DD.md` files.
3. Reply with:
   - CS: what they logged
   - Marketing: what they logged
   - Gaps: departments with no files
4. Do not invent work. Do not open another agent's private `/opt/data`.

## Live "ask them now"

You cannot inject a message into another container. Tell the admin to ping that department's bot, or leave a paper-trail request at `/opt/company/reports/<role>/_from_admin.md` (that file is what the department agent can see).

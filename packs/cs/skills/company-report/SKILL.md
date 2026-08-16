---
name: company-report
description: After a finished marketing or CS task, append a dated summary the admin can read.
version: 1.0.0
metadata:
  hermes:
    tags: [company, report]
    category: ops
---

# company-report

Write only under `/opt/company/reports/` (this role's mount). Do not write rules or skills.

## After a completed task

Append to `/opt/company/reports/YYYY-MM-DD.md`:

```
## HH:MM  <one-line title>
- What: ...
- Who asked: ...
- Outcome: ...
- Open items: ...
```

Keep it under 8 lines. No secrets, no full customer PII.

At the start of a turn, if `/opt/company/reports/_from_admin.md` exists, read it and answer those asks first.

## When the admin asks for a summary

Read the files in `/opt/company/reports/` for the requested dates and reply with a roll-up. Do not invent work that is not in those files.

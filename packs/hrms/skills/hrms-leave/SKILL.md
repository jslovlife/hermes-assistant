---
name: hrms-leave
description: Look up leave balance or file an HR ticket. Never change payroll.
version: 1.0.0
metadata:
  hermes:
    tags: [hrms, leave]
    category: hr
---

# hrms-leave

## Flow

1. Confirm who is asking (allowlisted user / employee ID).
2. Read-only: `get_leave_balance`, handbook resource.
3. To file a request, `create_hr_ticket` with dates and type. Do not approve leave yourself unless a tool named `approve_leave` exists **and** the operator said yes.

## Never

- Run payroll, change salary, or create accounts
- Quote another employee's balance to a peer

---
name: company-rules
description: Create or update company/department rule files. Admin only. Never edit SaaS skills.
version: 1.0.0
metadata:
  hermes:
    tags: [company, admin, rules]
    category: ops
---

# company-rules

## Allowed paths

- `/opt/company/rules/company.md`
- `/opt/company/rules/cs.md`
- `/opt/company/rules/marketing.md`
- `/opt/company/rules/<other-dept>.md` if that department exists

## How

1. Read the current file if it exists.
2. Propose the new bullet list in chat.
3. After the admin confirms, write the file (replace or append as they asked).
4. Confirm path + a 3-bullet recap.

## Never

- Edit `/opt/data/skills/**` or any `SKILL.md`
- Edit `/opt/repo/**`
- Put API keys, salaries, or customer PII in a rule file

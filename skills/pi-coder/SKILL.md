---
name: pi-coder
description: Delegate implementation work to pi-agent on OpenCode Go. Use for scaffolding, multi-file edits, tests, and refactors — not for one-line config tweaks.
version: 1.0.0
metadata:
  hermes:
    tags: [coding, pi, opencode]
    category: engineering
    requires_toolsets: [terminal]
---

# pi-coder

Hermes plans. **pi-agent** writes the code.

## When to use

- Scaffold a new app in `/opt/workspaces/<name>`
- Multi-file features, refactors, test suites
- Anything that would take more than ~3 file edits

Skip this skill for a single config line or a one-file script — use Hermes tools directly.

## Command

pi must run with Node >= 20. Prefer the nvm-wrapped binary:

```bash
export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1091
. "$NVM_DIR/nvm.sh"
nvm use 21 >/dev/null

cd "$WORKSPACE"

pi --print \
  --provider opencode-go \
  --model deepseek-v4-pro \
  "$TASK"
```

For cheap / high-volume edits, switch `--model deepseek-v4-flash`.

If `pi` is not on PATH after nvm use:

```bash
npx --yes @earendil-works/pi-coding-agent --print --provider opencode-go --model deepseek-v4-pro "$TASK"
```

## Task prompt to pass pi

Include:

1. Absolute workspace path
2. Stack constraints (from SOUL.md unless operator overrode)
3. Acceptance checks (commands to run)
4. "Do not commit unless asked. Do not deploy."

## After pi returns

- Read the diff (`git status` / `git diff`)
- Run the acceptance checks yourself
- Report files changed + how to run the app
- Do not deploy. Hand off to `gated-deploy` only after the operator asks.

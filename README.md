# Hermes Assistant (Docker)

Multi-tenant messaging agent: **Hermes in Docker**, OpenCode Go (DeepSeek Flash by default), isolated data per customer, industry packs (CS, marketing, admin, POS, HRMS, engineering). One client can have several roles under a company (shared rules + reports only).

**Host needs Docker + git.** No Hermes/Node/Python install for the bot. Optional Python 3 for the TMS console.

**Docs:** [User guide](docs/USER_GUIDE.md) · [Architecture](docs/ARCHITECTURE.md) · [TMS](docs/TMS.md) · [Slack setup](docs/SLACK_SETUP.md) · [Dashboard remote access](docs/DASHBOARD_REMOTE_ACCESS.md)

## Quick start

```bash
git clone <this-repo-url> assistant
cd assistant

./scripts/agent.sh new acme-cs cs
open "$(./scripts/agent.sh config acme-cs)"   # set OPENCODE_GO_API_KEY + Telegram (or Slack)
./scripts/agent.sh up acme-cs
./scripts/agent.sh doctor acme-cs
```

Operator console (localhost only):

```bash
TMS_PASSWORD='long-operator-password' ./scripts/tms.sh
# http://127.0.0.1:8787
```

## Commands

| Command | Purpose |
|---|---|
| `./scripts/agent.sh packs` | List industry packs |
| `./scripts/agent.sh new <name> [pack]` | Create a standalone tenant |
| `./scripts/agent.sh company new <co>` | Shared rules + reports for one client |
| `./scripts/agent.sh company role <co> <role>` | Create `<co>-<role>` (`cs`, `marketing`, `admin`, …) |
| `./scripts/agent.sh apply <name> <pack>` | SaaS-only: change pack; keeps `.env`, memory, and overlay |
| `./scripts/agent.sh overlay …` | Per-tenant custom tools (survives apply) |
| `./scripts/agent.sh up / down / restart / logs / doctor / backup <name>` | Lifecycle |
| `./scripts/tms.sh` | Web TMS (requires `TMS_PASSWORD`) |

Each tenant lives under `~/hermes-agents/<name>/` (`data/` + `workspaces/`). Secrets stay in that tenant’s `.env` — never commit them.

## Isolation

One container, one data dir, one bot token per tenant. No Docker socket. Write access only to `/opt/data` and `/opt/workspaces`. Shared image and read-only repo template.

Host root can still read volumes (normal SaaS). Paying tenants should use their own LLM key. Stronger isolation = on-prem or one VM per customer — same image.

## Channels

Telegram (default), Slack (Socket Mode, good for office POS/HRMS), WhatsApp Cloud API (official CS, needs a public webhook). See the user guide.

`scripts/tenant.sh` and `scripts/docker-gateway.sh` are legacy. Use `agent.sh` so you do not mix bot tokens.

## Lessons

Real incidents and how to avoid them — **[docs/LESSONS.md](docs/LESSONS.md)**: stuck
fresh-session search loops in group chats, and flaky `Broken pipe` LLM-API
connections. Every agent also inherits the `fresh-session-project-lookup` skill
from `skills/`, so it knows not to search forever for a project it was never told
about.

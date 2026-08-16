# Hermes Assistant — User Guide

This is the operator manual for the **Docker Hermes** product: one shared image, many isolated tenants, industry packs, and an optional localhost TMS console.

Diagrams: [ARCHITECTURE.md](ARCHITECTURE.md) · TMS console: [TMS.md](TMS.md)

The agent always runs **in Docker**. You do not install Hermes, Node, or Python runtimes for the bot itself. The host needs Docker, git, and (for TMS) Python 3.

---

## 1. What you are selling

A tenant is one bot: one Docker container, own data (memory, sessions, `.env`, skills), own workspace, own messaging token, one **industry pack**.

One **paying client** can have several tenants (roles) under a **company**. They share only rules and activity reports — never `.env`, `state.db`, or memories.

| Pack | Thinking (chat) | Coding worker | Typical channel |
|---|---|---|---|
| `cs` | Official DeepSeek PAYG | No | Telegram or WhatsApp Cloud API |
| `marketing` | Official DeepSeek PAYG | No | Telegram or Slack |
| `admin` | Official DeepSeek PAYG | No | Slack or Telegram (boss) |
| `pos` | Official DeepSeek PAYG | No | Slack (staff) |
| `hrms` | Official DeepSeek PAYG | No | Slack (HR group) |
| `engineer` | Official DeepSeek PAYG | Yes — OpenCode Go V4 Pro via pi | Telegram |

Writes that move money, payroll, prices, or production deploys stay **gated**: the agent must get an explicit yes in chat.

---

## 2. Isolation — what you can promise

**Yes**

- Tenant A cannot read Tenant B’s files, memory, or bot inbox.
- The agent can only write to `/opt/data` and `/opt/workspaces` (plus company report/rule paths when that role is mounted).
- No Docker socket is mounted. A tenant cannot start or stop other containers.
- Each container has a memory/CPU cap (default 4 GB / 2 CPU).

**No (unless you change the hosting model)**

- A host administrator with root can still read every volume. That is normal shared-SaaS. For HRMS/banks, deploy **on the customer’s server** or **one VM per tenant**.
- If every tenant uses the **same** OpenCode Go key, quota and provider logs are mixed. Give paying tenants their own key.
- Compose `deploy.resources` is Swarm-only; this repo also sets `mem_limit` / `cpus` so limits apply on plain Compose.

---

## 3. Minimum hardware

Models run in the cloud. **No GPU.**

| Role | Spec |
|---|---|
| Floor (1 chat tenant) | 2 vCPU, 2 GB RAM, 20 GB SSD, outbound HTTPS |
| Comfortable (recommended) | 2 vCPU, 4 GB RAM, 40 GB SSD |
| Extra tenant | about +2 GB RAM |
| Engineer pack + workspaces | 4 GB RAM, extra disk |

**Where to run Docker**

- **Mac Mini** — lab or 1–2 internal agents. Must stay powered and **never sleep**. Docker Desktop is OK; Linux Engine is cleaner.
- **On-prem Linux** (Ubuntu + Docker Engine) — best for POS/HRMS with local ERP.
- **Cheap VPS** (Hetzner, Lightsail, Contabo) — best 24/7 Telegram/Slack. About $5–12/month.
- **AWS** — only if the customer already has a VPC. `t4g.small` is enough. Do not buy GPU or EKS for this.

Telegram (long poll) and Slack (Socket Mode) need **no public inbound port**. WhatsApp Cloud API needs a public HTTPS webhook.

---

## 4. Host install

1. Install Docker and git.
2. Clone this repo once:

```bash
git clone <this-repo-url> assistant
cd assistant
```

3. Confirm Docker: `docker info`

Do not run a host `hermes gateway` and a Docker tenant on the **same** bot token.

---

## 5. Create a tenant (CLI)

```bash
# Customer-service tenant
./scripts/agent.sh new acme-cs cs
# Edit secrets
open "$(./scripts/agent.sh config acme-cs)"
# Required: OPENCODE_GO_API_KEY, TELEGRAM_BOT_TOKEN, TELEGRAM_ALLOWED_USERS
./scripts/agent.sh up acme-cs
./scripts/agent.sh doctor acme-cs
```

Useful commands:

```bash
./scripts/agent.sh list
./scripts/agent.sh packs
./scripts/agent.sh apply acme-cs pos    # change industry; keeps .env and memory
./scripts/agent.sh logs acme-cs
./scripts/agent.sh restart acme-cs
./scripts/agent.sh down acme-cs         # keeps data
./scripts/agent.sh backup acme-cs
./scripts/agent.sh restore acme-cs /path/to/old/data
./scripts/agent.sh rename acme-cs acme-support
```

`apply` copies pack `SOUL.md`, `config.yaml`, pack skills, and the pack MCP allowlist. It **never** overwrites `.env`, `state.db`, memories, `skills-custom/`, or `mcp.allow.custom.yaml`. Runtime skills are then **write-locked**. Only the SaaS team (this CLI / TMS) can add or change predefined skills. A company admin in chat cannot.

After `apply`, `restart` so Hermes reloads SOUL/config.

### Custom tools for one customer (overlay)

When one client needs their own API / MCP, do **not** fork the industry pack and do **not** let them paste an `npx` URL. Install an overlay on **that tenant only**:

```bash
# 1. Skill playbook (unique name, not a pack skill)
cp -R overlays/example-http-lookup /tmp/acme-orders
# edit /tmp/acme-orders/SKILL.md
./scripts/agent.sh overlay add-skill acme-cs /tmp/acme-orders

# 2. Allow their tool names (merged with the pack allowlist)
./scripts/agent.sh overlay mcp acme-cs overlays/example-mcp.allow.yaml

# 3. Their MCP URL / token in that tenant's .env only
#    CUSTOM_MCP_URL=…  CUSTOM_MCP_TOKEN=…
# 4. Install the MCP server on that container, then:
./scripts/agent.sh restart acme-cs
./scripts/agent.sh overlay list acme-cs
```

| File | Who writes it | Survives `apply`? |
|---|---|---|
| `data/skills-custom/<id>/SKILL.md` | SaaS (`overlay add-skill`) | Yes |
| `data/mcp.allow.custom.yaml` | SaaS (`overlay mcp` or TMS) | Yes |
| `data/skills/` | Generated (pack + overlay) | Rebuilt |
| `data/mcp.allow.yaml` | Generated merge | Rebuilt |
| `data/mcp.allow.pack.yaml` | Last applied pack | Replaced on apply |

`apply acme-cs cs` refreshes pack files and **re-merges** the overlay. Other tenants never see Acme’s tools.

TMS has the same overlay panel (SaaS only). Put `CUSTOM_MCP_URL` / `CUSTOM_MCP_TOKEN` in that tenant’s secrets. On-prem customers run the MCP on their LAN; you still own the allowlist.

### Company with multiple roles (CS + marketing + admin)

One client who wants a CS bot, a marketing bot, and a boss who sets rules and asks for summaries:

```bash
./scripts/agent.sh company new acme
./scripts/agent.sh company role acme admin
./scripts/agent.sh company role acme cs
./scripts/agent.sh company role acme marketing
# Each role is its own bot token
open "$(./scripts/agent.sh config acme-admin)"
open "$(./scripts/agent.sh config acme-cs)"
open "$(./scripts/agent.sh config acme-marketing)"
./scripts/agent.sh up acme-admin
./scripts/agent.sh up acme-cs
./scripts/agent.sh up acme-marketing
```

**Who can do what**

| Actor | Can do | Cannot do |
|---|---|---|
| Company **admin** agent (boss) | Write `/opt/company/rules/company.md` or `cs.md` / `marketing.md`; read all department reports; ask the human to ping a department bot | Edit pack `SKILL.md` files; reach into another container’s memory; apply packs |
| **CS** / **marketing** agents | Read company + their department rules (read-only); append dated notes under their report folder | Change rules; change skills |
| **SaaS team** (you, via `apply` / overlay / TMS) | Add pack skills, tenant overlay skills, and MCP allow names | — |

Shared disk (not a message bus):

```
~/hermes-agents/companies/acme/
  company.yaml
  shared/rules/{company.md,cs.md,marketing.md}
  shared/reports/{cs,marketing}/YYYY-MM-DD.md
~/hermes-agents/acme-admin/     # rules + all reports, read-write
~/hermes-agents/acme-cs/        # rules ro; only reports/cs rw
~/hermes-agents/acme-marketing/
```

Admin “what did CS do?” = read those report files (skill `company-briefing`). Live “ask CS now” = the human messages the CS bot, or admin leaves `/opt/company/reports/cs/_from_admin.md`. Do not share one `state.db` across roles.

If you pull seeder changes, rebuild the shared image once:

```bash
docker compose -f docker/agent-compose.yml --project-directory . build
```

---

## 6. TMS web console (operator)

Full screen-by-screen guide: **[TMS.md](TMS.md)**.

The TMS is a localhost website that calls `agent.sh`. It does **not** mount `docker.sock` and it is **not** in the chat path.

```bash
TMS_PASSWORD='choose-a-long-operator-password' ./scripts/tms.sh
```

Open [http://127.0.0.1:8787](http://127.0.0.1:8787). Sign in with `TMS_PASSWORD`.

You can create tenants and companies, start/stop, apply packs, add overlays, save `.env` keys, run doctor/logs, and backup `data/`.

Company admins set rules **in chat**. Do not give them TMS. **Do not** publish port 8787. Override: `TMS_HOST=127.0.0.1 TMS_PORT=8787`.

---

## 7. Channels

Hermes is one process with many adapters. Pack + SOUL stay the same; you fill different env keys.

### Telegram (default)

1. `@BotFather` → `/newbot` → token → `TELEGRAM_BOT_TOKEN`
2. `@userinfobot` → **numeric** user id → `TELEGRAM_ALLOWED_USERS` (not the bot username)
3. DM the bot `/start`

Optional group: `TELEGRAM_GROUP_ALLOWED_CHATS`. Privacy mode on BotFather must be disabled if the bot should see group messages.

### Slack (office POS / HRMS)

1. [api.slack.com/apps](https://api.slack.com/apps) → Create app
2. Enable **Socket Mode** (outbound only; no public URL)
3. Bot token `xoxb-…` and app-level token `xapp-…` with `connections:write`
4. Scopes: `chat:write`, `im:history`, `im:read`, `im:write`, `app_mentions:read`, plus channel history if you use channels
5. `SLACK_BOT_TOKEN`, `SLACK_APP_TOKEN`, `SLACK_ALLOWED_USERS`

### WhatsApp

- **Cloud API** (official CS): Meta Business, verified number, **public HTTPS webhook**. Use this for paying customers.
- Unofficial QR/Baileys pairing is not recommended for production.

You may enable Telegram and Slack on the same tenant with separate allowlists. Sessions are per channel unless the user `/resume`s. Never run two containers on the same bot token.

---

## 8. Models and cost

**Do not use OpenRouter.** It is a markup gateway (Gemini/Claude/etc.) and will surprise you on the bill.

| Lane | Provider | When |
|---|---|---|
| Thinking / chat / summaries | Official DeepSeek PAYG (`DEEPSEEK_API_KEY`, model `deepseek-v4-flash`) | Every message |
| Coding (engineer pack only) | OpenCode Go (`OPENCODE_GO_API_KEY`, pi-agent `deepseek-v4-pro`) | Implementation only |

Official DeepSeek list is typically about `$0.14 / $0.28` per 1M tokens for the cheap chat model — far below OpenRouter’s paid SKUs. OpenCode Go’s $10 plan is reserved for **coding**, not 24/7 chat.

Each paying tenant gets its **own** DeepSeek key. Engineer tenants also get their own Go key. Leave `OPENROUTER_API_KEY` empty.

---

## 9. Industry MCP (POS / HRMS / CS)

Packs include `mcp.allow.yaml` — the **names** of tools that may exist. You still must install the real MCP server (orders, tickets, HRIS) and whitelist those names in Hermes. Until the MCP is connected, the agent will say the lookup is missing; that is expected.

A **per-tenant overlay** (`mcp.allow.custom.yaml`) is merged on top of the pack list so one customer’s tools do not land in the shared pack.

Gated tool names (refund, payroll, `set_price`, or a customer’s `acme_refund`) must not run without an operator yes, even if the MCP is installed.

Do not let a tenant paste arbitrary `npx` MCP URLs. Only your catalog plus overlays you reviewed.

---

## 10. Backups and restore

```bash
./scripts/agent.sh backup acme-cs
# prints a tar.gz under ~/hermes-agents/acme-cs/backups/
```

Caches (`home`, `lsp`, `cache`) are excluded. To bring a tenant back after deleting the container:

```bash
./scripts/agent.sh restore acme-cs /path/to/extracted/data
./scripts/agent.sh up acme-cs
```

Containers are disposable. **Data dirs are not.**

---

## 11. Troubleshooting

| Symptom | Check |
|---|---|
| Bot never replies | `doctor`; numeric allowlist; unique token; `logs` |
| Telegram hang on Docker Desktop | Keep `force_ipv4` and `HERMES_TELEGRAM_*` timeouts from `.env.example` |
| `empty section between colons` | Volume env not set — always use `agent.sh up`, not raw compose |
| Broken pipe on DeepSeek stream | Raise `agent.api_max_retries` / `auxiliary.transient_retries`; keep a fallback provider. See docs/LESSONS.md (NOT `gateway.streaming: false` — that key only affects rendering). |
| 409 Conflict | Two processes polling the same Telegram token |
| Pack changed but personality did not | `apply` then `restart` |
| Admin cannot see CS reports | Role was created with `company role` (not plain `new`); recreate container after compose change |
| Agent says it cannot write a report | `HERMES_WRITE_SAFE_ROOT` must include `/opt/company/reports` (set by `company role`) |
| Custom skill vanished after apply | It was copied into `skills/` only. Put it in `skills-custom/` via `overlay add-skill` |
| TMS will not start | `TMS_PASSWORD` must be set |

---

## 12. Directory map

```
packs/<cs|marketing|admin|pos|hrms|engineer>/
scripts/agent.sh                tenant + company lifecycle
scripts/tms.sh                  localhost operator console (SaaS only)
tms/                            TMS server (Python stdlib)
docs/ARCHITECTURE.md            system diagrams
docs/TMS.md                     TMS operator guide
docker/agent-compose.yml        one container per tenant
~/hermes-agents/<name>/data     that tenant’s memory and .env   (not in git)
~/hermes-agents/<name>/data/skills-custom   tenant overlay (survives apply)
~/hermes-agents/<name>/data/mcp.allow.custom.yaml
~/hermes-agents/<name>/workspaces
~/hermes-agents/companies/<co>/shared/rules|reports
overlays/                       example custom skill + MCP allow (copy, then overlay add-skill)
```

Legacy `scripts/tenant.sh` / `docker-gateway.sh` are superseded by `agent.sh`. Do not mix them on the same bot token.

---

## 13. Checklist for a new customer

1. Agree hosting: their Mini/Linux box vs your VPS vs dedicated VM.
2. Single bot: `agent.sh new <slug> <pack>`. Multi-role client: `company new` then `company role` for `admin`, `cs`, `marketing`.
3. Each role gets its own Go (or DeepSeek) key + channel token + allowlist in `.env`
4. `up` + `doctor` + a test DM
5. Connect industry MCP when the POS/HRIS API exists. One-off customer APIs go in that tenant’s **overlay**, not the shared pack.
6. Nightly `backup` of each role’s `data/`
7. TMS only on localhost/VPN for **your** operators — not the client’s admin agent

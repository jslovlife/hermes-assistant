# Hermes Assistant (Docker)

Multi-agent Hermes messaging assistant. One Docker image, many isolated agents — each with its own data, bot token, persona ("soul"), and optional role ("pack"). Built for teams and companies that want dedicated, isolated assistants per role.

**Docs:** [User guide](docs/USER_GUIDE.md) · [Architecture](docs/ARCHITECTURE.md) · [TMS](docs/TMS.md) · 中文版 [README.zh-CN.md](README.zh-CN.md)

> **Host needs only Docker + git.** No Hermes/Node/Python install for the bots. Optional Python 3 for the TMS console.

---

## 1. How to start (quick start)

### 1.1 Clone and set up one agent

```bash
git clone <this-repo-url> assistant
cd assistant

# Create an agent. Pick a persona:
./scripts/agent.sh new my-bot                 # neutral general assistant
./scripts/agent.sh new my-bot --soul engineer # standalone engineering persona
./scripts/agent.sh new my-bot cs              # a full role pack (customer service)

# Find and edit the agent's .env (set API keys + channel token):
open "$(./scripts/agent.sh config my-bot)"

# Start it and check health:
./scripts/agent.sh up my-bot
./scripts/agent.sh doctor my-bot
```

The `.env` path (printed by `config`) is where you set:
- `DEEPSEEK_API_KEY` — the thinking model key.
- `TELEGRAM_BOT_TOKEN` / `TELEGRAM_ALLOWED_USERS` — the messaging channel.
- `OPENCODE_GO_API_KEY` — only if you chose a coding pack (`engineer`).

### 1.2 List what's available

```bash
./scripts/agent.sh list     # all agents + running state + pack
./scripts/agent.sh packs    # all available role packs
```

### 1.3 Operator console (optional, localhost only)

```bash
TMS_PASSWORD='choose-a-long-operator-password' ./scripts/tms.sh
# http://127.0.0.1:8787
```

---

## 2. Souls vs packs (persona vs full role)

| | Soul | Pack |
|---|---|---|
| Content | `SOUL.md` (persona only) | `SOUL.md` + config + skills + MCP allowlist + required env |
| Command | `new <name> --soul <soul>` | `new <name> <pack>` |
| Example souls | `general`, `omni`, `engineer`, `devops`, `qa`, `security`, `pm`, `cto` | `cs`, `engineer`, `devops`, `qa`, `security`, `pm`, `cto`, `admin`, `marketing`, `pos`, `hrms` |
| Skill source | shared `skills/` (loaded on demand) | its own `packs/<pack>/skills/` |

- **Soul** = personality only; capability comes from the shared `skills/` library (loaded on demand, so it stays light).
- **Pack** = a self-contained deployable role (persona + skills + config + MCP + required env). Best for one-command reproducible setup.
- **`omni` soul** = one agent that acts as engineer / DevOps / QA / security / PM / CTO, loading each domain skill on demand — for a single person who wants "one agent, every hat."

---

## 3. Companies, roles & isolation

Create a company, add role-agents to it, and agents **not in the company have zero access** to its data.

```bash
# 1. Create the company (shared rules/ + reports/)
./scripts/agent.sh company new acme

# 2. Add role-agents (one bot token each)
./scripts/agent.sh company role acme admin     # boss: write rules + read all reports
./scripts/agent.sh company role acme devops
./scripts/agent.sh company role acme qa
./scripts/agent.sh company role acme security

# 3. Start them
./scripts/agent.sh up acme-admin
./scripts/agent.sh up acme-devops
```

**Permission matrix** (enforced by container mounts + filesystem + Hermes write-safe-root):

| Agent | company `rules/` | company `reports/` |
|---|---|---|
| `<co>-admin` | read+write | read all + write |
| `<co>-<role>` (e.g. devops) | read-only | only its own `reports/<role>/` |
| another company's agent | ❌ no mount | ❌ no mount |
| standalone (no company) agent | ❌ no mount | ❌ no mount |

The isolation is **physical**: a company's directories are mounted only into that company's agents' containers. Unrelated agents can't even see them.

> **Honest caveat:** this isolates agents/companies from each other. The **host machine operator (root) can still read all volumes** — normal for SaaS. For isolation from the machine owner too, use one VM/on-prem per company (same image).

---

## 4. Daily maintenance

### 4.1 Edit an agent's `.env` (e.g. rotate a bot token / API key)

```bash
# 1. Find the .env path
./scripts/agent.sh config my-bot          # prints: /path/to/~/hermes-agents/my-bot/data/.env

# 2. Edit it (nano/vim/code)
vim "$(./scripts/agent.sh config my-bot)"

# 3. Apply: restart the container so Hermes reloads the new secrets
./scripts/agent.sh restart my-bot
```

`.env` is **never committed** — it lives only in the agent's data dir.

### 4.2 Restart / stop / start / status

```bash
./scripts/agent.sh restart my-bot   # stop + start (keeps data)
./scripts/agent.sh down  my-bot     # stop container (keeps data)
./scripts/agent.sh up    my-bot     # start again
./scripts/agent.sh status my-bot    # is it running?
./scripts/agent.sh logs  my-bot     # tail its logs
./scripts/agent.sh list             # all agents + state
```

### 4.3 Change a running agent's role (pack)

```bash
./scripts/agent.sh apply my-bot devops   # changes pack; keeps .env, memory, overlay
./scripts/agent.sh restart my-bot        # reload SOUL/config
```

### 4.4 Backup / restore

```bash
./scripts/agent.sh backup my-bot     # -> ~/hermes-agents/my-bot/backups/my-bot-<ts>.tar.gz
```
Backups include `.env`, memory, state.db, skills, overlay. Copy tarballs off the host.

---

## 5. Recovery — the agent died and I can't reach it on Telegram/Slack

> **Key principle: you manage a down agent from the HOST terminal, not through its chat.** If the bot doesn't answer on Telegram/Slack, it's a host-side problem — fix it on the machine, not in the chat.

### 5.1 Diagnose

```bash
./scripts/agent.sh status my-bot   # is the container up?
./scripts/agent.sh logs  my-bot    # what error is it throwing?
./scripts/agent.sh doctor my-bot   # checks Docker, container, and secrets
```
`doctor` prints `ok`/`FAIL` for: Docker daemon, data dir, container running, and required keys in `.env`.

### 5.2 Fix by severity

| Symptom | Fix |
|---|---|
| Container crashed, data intact | `./scripts/agent.sh restart my-bot` |
| Won't start, token/key looks wrong | `config my-bot` → edit `.env` → `restart` |
| Token revoked / bot removed | Create a new token, edit `.env`, `restart` |
| Container missing but data exists | `./scripts/agent.sh restore my-bot <data-dir>` then `up` — memory/state/.env are re-attached, not recreated |
| Data lost | Extract `backup` tarball, `restore` it, then `up` |
| Seeder / Dockerfile changed | `./scripts/agent.sh down` → rebuild image → `up` |
| Still won't start | `logs my-bot` — read the actual error and check the channel token / network (Telegram is outbound-only) |

### 5.3 The recovery ladder (when nothing answers on chat)

1. **Host check:** `status` → `logs` → `doctor`.
2. **Soft restart:** `restart`.
3. **Config fix:** verify/edit `.env` (token, allowed users), `restart`.
4. **Re-attach data:** if the container is gone but data dir exists → `restore <name> <data-dir>` → `up`.
5. **From backup:** if data is lost → unpack the latest tarball → `restore` → `up`.
6. **Image:** if it still won't boot after config looks right, rebuild the image (seeder/Dockerfile changes need a rebuild).

> Rule of thumb: **containers are disposable; data dirs are not.** You almost never lose the agent's memory if you keep the data dir (and backups).

---

## 6. Architecture at a glance

- One shared image; each agent = its own container + data dir + workspace + bot token.
- Container paths are neutral: `/opt/repo` (read-only template), `/opt/data` (agent data), `/opt/workspaces` (agent files), `/opt/company/` (company rules/reports when mounted).
- No `docker.sock`, no privileged, resource limits (default 4 GB / 2 CPU / 256 PIDs).
- Write-safe roots restrict what each agent can write.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and [docs/USER_GUIDE.md](docs/USER_GUIDE.md) for details.

## 7. Common commands reference

| Command | Purpose |
|---|---|
| `new <name> [pack\|--soul <soul>]` | Create an agent |
| `apply <name> <pack>` | Change a running agent's pack (keeps `.env`/memory/overlay) |
| `up / down / restart <name>` | Lifecycle |
| `logs / status / doctor <name>` | Inspect |
| `config <name>` | Print the `.env` path |
| `backup / restore <name>` | Data backup & re-attach |
| `company new/role/list` | Multi-role company setup |
| `overlay add-skill/rm-skill/mcp` | Per-agent custom tools |
| `rename <old> <new>` | Rename an agent (moves data, keeps memory) |
| `tms.sh` | Web console (requires `TMS_PASSWORD`) |

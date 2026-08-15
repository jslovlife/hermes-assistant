# Hermes Assistant (Docker-first)

A reusable, per-environment Telegram assistant: **everything runs in Docker**.
OpenCode Go (DeepSeek V4) for thinking, coding, and auxiliary work.

**Host requirement: Docker only.** No `uv`, `nvm`, `node`, `hermes`, or `pi` on the host.

This repo is the **control plane**: versioned config, soul, skills, and install scripts.
Runtime state lives in `~/.hermes/`. Secrets live in `.env` — **never committed**.

## One repo → many isolated assistants

Each deployment is a separate clone with its own `.env` (secrets) and
`config/SOUL.md` (persona). Nothing is shared — keys are never committed.

> Example: "assistant for Company A" = a fresh clone with Company A's bot token,
> allowlist, provider keys, and a SOUL.md that focuses it on Company A's work.

### One clone → many agents (`scripts/agent.sh`)

If you'd rather **clone once** and spin up several independent agents from that
single clone, use `agent.sh` instead of per-tenant clones. Each agent gets its
own container, its own data dir, its own workspace, and its own bot token — with
**no per-agent clone and no rebuild**. Container paths are neutral
(`/opt/repo`, `/opt/workspaces`, `/opt/data` — no branding).

```bash
git clone <this-repo-url> assistant
cd assistant

scripts/agent.sh new alice        # create agent "alice" (own data + workspace + .env)
scripts/agent.sh config alice     # prints the path to alice's .env
#   → edit that .env: set TELEGRAM_BOT_TOKEN + TELEGRAM_ALLOWED_USERS
scripts/agent.sh up alice         # start it in its own container

scripts/agent.sh new bob          # a second independent agent, same single clone
scripts/agent.sh up bob

scripts/agent.sh list             # all agents + running status
scripts/agent.sh logs alice       # tail logs
scripts/agent.sh down bob         # stop (keeps data)
```

Per-agent layout under `$HOME/hermes-agents/<name>/`:
- `data/` — sessions, memories, `.env`, skills, logs (mounted at `/opt/data`)
- `workspaces/` — the agent's project files (mounted at `/opt/workspaces`)

The shared repo is mounted read-only at `/opt/repo`; the seeder copies config,
SOUL, and skills from it on each agent's first boot. Each agent's `.env` stays
separate, so every agent has its own Telegram bot and its own keys.

### Recovering an agent after deleting its container (`restore`)

**Containers are disposable; the agent's data lives on the host.** All memories,
`state.db`, `.env`, and skills live in the agent's data dir, which is a bind-mount
from the host — deleting the container does **not** delete the data.

To bring an agent back under a new name (keeping all memory), just point the name
at the existing data dir:

```bash
# find the data dir of the old agent (it's the host path bind-mounted to /opt/data)
scripts/agent.sh restore <newname> <path-to-existing-data>
scripts/agent.sh up <newname>
```

Example — resurrect the old `jojopa` agent as `newma`, memory intact:

```bash
scripts/agent.sh restore newma ~/hermes-tenants/jojopa/data
scripts/agent.sh up newma
```

`restore` writes an `agent.conf` override that records where the data lives, so
`list`, `config`, `up`, `logs`, etc. all work against the re-attached data.

### Fully renaming an agent (`rename`)

To change an agent's name **and** rename its data folder (a clean rename, not
just re-attachment), use `rename`. It stops + removes the old container, moves
the data dir to a path under the new name, and re-registers — memory carried
over because the folder itself is moved, not recreated.

```bash
scripts/agent.sh rename <old> <new>
scripts/agent.sh up <new>
```

Example — rename the old `jojopa` agent to `newma` (folder + container):

```bash
scripts/agent.sh rename jojopa newma
scripts/agent.sh up newma
```

Works for both the default layout (`$HOME/hermes-agents/<name>/data`) and the
older `$HOME/hermes-tenants/<name>/data` layout (via an existing `agent.conf`).
It refuses to overwrite an existing target name and refuses `old == new`.




## Prerequisites

- **Docker** (Desktop on macOS/Windows, Engine on Linux) — installed and running.
- **git**.

That's it. No Python, Node, or Hermes install on the host.

## Quick start

1. **Clone** — `git clone <this-repo-url> assistant`
2. **Go in** — `cd assistant`
3. **Create your secrets** — `cp .env.example .env`, then fill in:
   - `OPENCODE_GO_API_KEY` — from [opencode.ai/auth](https://opencode.ai/auth) → create a workspace key
   - `TELEGRAM_BOT_TOKEN` — message `@BotFather` on Telegram → `/newbot` → copy the token
   - `TELEGRAM_ALLOWED_USERS` — message `@userinfobot` → copy your **numeric** user ID (digits only, not the bot)
4. **Start** — `./scripts/docker-gateway.sh up` (first run pulls the prebuilt image; then it's live)
5. **Verify** — `./scripts/doctor.sh` and message your bot in Telegram.

That's it. No other install steps.

### Secrets (.env)

| Key | Where | Required |
|---|---|---|
| `OPENCODE_GO_API_KEY` | [opencode.ai/auth](https://opencode.ai/auth) → workspace keys | ✅ |
| `TELEGRAM_BOT_TOKEN` | Telegram `@BotFather` → `/newbot` | ✅ |
| `TELEGRAM_ALLOWED_USERS` | Telegram `@userinfobot` → your numeric ID | ✅ |
| `OPENROUTER_API_KEY` | [openrouter.ai](https://openrouter.ai) → API keys | Optional (per-token overflow fallback) |

`.env` is gitignored — your keys never leave the machine.

On first boot, the container auto-seeds `.env`, `config.yaml`, `SOUL.md`, and `skills/`
from the repo into `~/.hermes/`. To update secrets later, either:
- Delete `~/.hermes/.jsec-init-done` and restart, or
- Edit `~/.hermes/.env` directly.

## Model routing

| Job | Provider | Model |
|---|---|---|
| Thinking (chat / planning / analysis) | OpenCode Go | `deepseek-v4-flash` |
| Coding (pi-agent) | OpenCode Go | `deepseek-v4-pro` |
| Auxiliary (compression / review / title) | OpenCode Go | `deepseek-v4-flash` |

## Behind a VPN / firewall

> **Most setups need NO proxy.** The assistant connects directly to Telegram and
> opencode.ai out of the box. Only configure a proxy if your network actually blocks
> those hosts (e.g. mainland China) — and you must have a local proxy client
> (Clash/Surge/V2Ray) running; an empty or unreachable proxy breaks everything.

The assistant needs outbound access to Telegram, GitHub, and opencode.ai — blocked
or throttled in some regions (e.g. mainland China). A VPN solves this, but Docker
Desktop does **not** inherit the Mac's VPN automatically. Configure it in two places:

**Build time (once)** — the base image is pulled from Docker Hub
(`nousresearch/hermes-agent`), no ghcr.io involved. If Docker Hub is also slow in your
region, add a registry mirror in Docker Desktop → Settings → Docker Engine, e.g.
`{"registry-mirrors": ["https://docker.m.daocloud.io"]}`, then Apply & Restart.

**Runtime** — so the running container can reach Telegram/GitHub/opencode. Add to
`.env` (next to your keys):

```bash
HTTP_PROXY=http://host.docker.internal:7890
HTTPS_PROXY=http://host.docker.internal:7890
```

Replace `7890` with your VPN client's local proxy port (Clash `7890`, Surge `6152`).

> Tip: use your VPN client's **rule mode** to route only `github.com`, `ghcr.io`,
> `api.telegram.org`, and `opencode.ai` through the proxy, keeping the rest of your
> traffic direct — so the assistant never slows down your other work.

## GitLab (self-hosted)

The assistant can work with GitLab (usually self-hosted). Configure per deployment:

- `.env`: `GITLAB_URL` + `GITLAB_TOKEN`
- SSH key for `git clone` / `git push`

See the `gitlab` skill for full setup (SSH key, REST API, merge requests).

## Customize per deployment

- `config/SOUL.md` — who the assistant is and what it focuses on (edit for each company).
- `config/hermes.config.yaml` — provider/model routing, gateway options.
- `.env` — secrets (never committed).

## Daily commands

| Command | Purpose |
|---|---|
| `./scripts/docker-gateway.sh status/logs/restart` | Manage the container |
| `./scripts/doctor.sh` | Health check (Docker + secrets) |

## Multi-tenant (running several companies)

Each **company = one fully isolated Hermes instance** with its own bot token,
its own runtime data (state.db / memory / skills / secrets), its own container
and image. This is the "one company per clone/container" model.

Two tenants are set up:

- **`newma`** — the current install (this repo + `~/.hermes`). Handled by
  `tenants/newma.conf` which points at the existing paths.
- **`jojopa`** — a brand-new tenant scaffolded under `~/hermes-tenants/jojopa`.
  Fill its bot token before first start.

Manage everything with the tenant manager:

```bash
./scripts/tenant.sh list                      # list tenants + running containers
./scripts/tenant.sh up   jojopa               # build image + start jojopa
./scripts/tenant.sh down jojopa               # stop jojopa (keeps its data)
./scripts/tenant.sh logs  jojopa              # tail jojopa logs
./scripts/tenant.sh status jojopa             # container status
```

**Create a brand-new company (Company C):**

```bash
# 1. Start it — `up` auto-clones the template repo and seeds a .env placeholder
./scripts/tenant.sh up company-c
#    -> clones repo to ~/hermes-tenants/company-c/repo
#    -> seeds ~/hermes-tenants/company-c/data/.env (fill it before the bot works)

# 2. Fill in the bot token + your Telegram ID
open -e ~/hermes-tenants/company-c/data/.env
#    set TELEGRAM_BOT_TOKEN and TELEGRAM_ALLOWED_USERS

# 3. Start again (now that the bot token is set)
./scripts/tenant.sh up company-c
```

(For an existing tenant whose repo is already present, `up` just builds/start.)

**Isolation guarantees:** each tenant mounts its **own** repo at `/opt/jsec`
and its **own** data dir at `/opt/data`. `.env`, `state.db`, memory, and skills
are per-tenant — no shared state between companies. Each bot token is unique,
so no `409 Conflict` collisions.

## Troubleshooting

**The bot never responds / gateway logs show `Connecting to Telegram (attempt 1/8)` or timeouts.**
The Docker Desktop (macOS) container VM has no working IPv6 route, and the Python
Telegram stack tries IPv6 first. The fix is already shipped in `.env.example` and
`config/hermes.config.yaml` — make sure your `.env` includes:

```bash
HERMES_TELEGRAM_DISABLE_FALLBACK_IPS=1
HERMES_TELEGRAM_HTTP_READ_TIMEOUT=120
HERMES_TELEGRAM_HTTP_CONNECT_TIMEOUT=20
```
(and `force_ipv4: true` is under `network:` in `config/hermes.config.yaml`). Then
`./scripts/docker-gateway.sh restart`. These are harmless on machines with IPv6.

**`Name or service not known` for api.telegram.org.** The host DNS can't resolve
Telegram (blocked/poisoned DNS). Try `TELEGRAM_FALLBACK_IPS=149.154.166.110` in `.env`,
or fix the host's DNS.

**Bot still won't respond after starting.** Check:
- The token is correct and unique — `@BotFather` → `/token`. One bot = one token; a
  second instance polling the same bot causes `409 Conflict` and connection resets.
- `TELEGRAM_ALLOWED_USERS` is your numeric ID, not the bot username.
- `./scripts/doctor.sh` shows all secrets set.

## Layout

```
config/hermes.config.yaml   → auto-seeded to ~/.hermes/config.yaml on first boot
config/SOUL.md              → auto-seeded to ~/.hermes/SOUL.md
skills/*                    → layered onto baked skills
.env                        → secrets (gitignored)
docker/Dockerfile           → thin wrapper (FROM hermes-agent:base + pi-agent)
docker/docker-compose.yml   → gateway container
scripts/docker-gateway.sh   → build + run
scripts/doctor.sh           → health check
```

## Safety & security model

The agent runs in an isolated Docker container. **What it can do:**

- Read/write **only** two directories: `~/.hermes` (its own runtime data) and the
  repo clone (where it commits code). Everything else on your machine is out of reach.
- Make outbound network calls (Telegram, opencode.ai, GitHub) to do its job.

**What it cannot do** (by design):

- **No host control** — the Docker socket is **not** mounted, so the container
  cannot start/inspect/stop containers or reach the host daemon.
- **No privileged mode, no host network, no host PID/namespace.**
- **Hardened** — resource limits (4 GB RAM, 2 CPU), a process cap, and
  `no-new-privileges` prevent a runaway agent loop from starving or escalating on
  the host.

**Secrets & keys:**

- Live in `.env`, which is **gitignored and never committed**.
- Never pasted into chat — the agent reads them from env / `.env` only.
- One Telegram bot per token; don't attach a second integration to the same token.

**Production deploys** need an explicit "deploy prod" yes from the operator.

The container image is built from the public `nousresearch/hermes-agent` base plus
the public `@earendil-works/pi-coding-agent` npm package — a transparent, verifiable
supply chain (both are open source).
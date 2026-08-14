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

## Safety

- **Never commit `.env`.** Keys are per-instance and isolated.
- One Telegram bot per token — do not attach a second integration to the same token.
- Production deploys need an explicit yes.
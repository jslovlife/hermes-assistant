# Hermes Assistant (Docker-first)

A reusable, per-environment Telegram assistant: **everything runs in Docker**.
OpenCode Go (Grok 4.5 + DeepSeek V4) for thinking, coding, and auxiliary work.

**Host requirement: Docker only.** No `uv`, `nvm`, `node`, `hermes`, or `pi` on the host.

This repo is the **control plane**: versioned config, soul, skills, and install scripts.
Runtime state lives in `~/.hermes/`. Secrets live in `.env` — **never committed**.

## One repo → many isolated assistants

Each deployment is a separate clone with its own `.env` (secrets) and
`config/SOUL.md` (persona). Nothing is shared — keys are never committed.

> Example: "assistant for Company A" = a fresh clone with Company A's bot token,
> allowlist, provider keys, and a SOUL.md that focuses it on Company A's work.

## Quick start

1. `git clone <your-repo-url> assistant`
2. `cd assistant`
3. `cp .env.example .env` — fill in your keys
4. `./scripts/docker-gateway.sh up` — first run pulls the prebuilt base image, then it just works

That's it. No other install steps.

### Secrets (.env)

| Key | Where |
|---|---|
| `OPENCODE_GO_API_KEY` | [opencode.ai/auth](https://opencode.ai/auth) → workspace keys (all models) |
| `TELEGRAM_BOT_TOKEN` | Telegram `@BotFather` → `/newbot` |
| `TELEGRAM_ALLOWED_USERS` | Telegram `@userinfobot` → your numeric ID |

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
# Telegram (blocked in some regions) has its own proxy var — set this FIRST:
TELEGRAM_PROXY=http://host.docker.internal:7890
# General outbound (GitHub/opencode) — optional if only Telegram is blocked:
HTTP_PROXY=http://host.docker.internal:7890
HTTPS_PROXY=http://host.docker.internal:7890
```

Replace `7890` with your VPN client's local proxy port (Clash `7890`, Surge `6152`).
Use `host.docker.internal` (the host as seen from inside Docker), not `127.0.0.1`.
If Telegram still shows `Name or service not known` / fallback-IP failures, the
container isn't reaching the proxy — ensure the VPN is running on the host and
Docker can reach it, then restart.

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
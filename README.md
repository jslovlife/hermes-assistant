# Hermes Assistant (Docker-first)

A reusable, per-environment Telegram assistant: **everything runs in Docker**.
OpenRouter (DeepSeek V4) for thinking, OpenCode Go (DeepSeek V4) for coding via pi-agent.

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
4. `./scripts/docker-gateway.sh up` — first run builds images (~15 min), then it just works

That's it. No other install steps.

### Secrets (.env)

| Key | Where |
|---|---|
| `OPENROUTER_API_KEY` | [openrouter.ai](https://openrouter.ai) → API keys (thinking model) |
| `OPENCODE_GO_API_KEY` | [opencode.ai/auth](https://opencode.ai/auth) → workspace keys (coding / pi-agent) |
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
| Thinking (chat / planning / analysis) | OpenRouter | `deepseek/deepseek-v4-pro` |
| Coding (pi-agent) | OpenCode Go | `deepseek-v4-pro` |
| Auxiliary (compression / review / title) | OpenCode Go | `deepseek-v4-flash` |

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
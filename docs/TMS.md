# TMS — Tenant Management System

Operator console for Hermes Assistant. Localhost website that wraps `scripts/agent.sh`. It is **SaaS-only**. It is **not** in the Telegram/Slack/WhatsApp path.

Architecture: [ARCHITECTURE.md](ARCHITECTURE.md) · Product: [USER_GUIDE.md](USER_GUIDE.md)

---

## 1. What TMS is

| It does | It does not |
|---|---|
| Create tenants and companies | Talk to customers |
| Start / stop / restart containers | Mount `docker.sock` |
| Apply industry packs | Let a company admin add skills |
| Write allowlisted keys into that tenant’s `.env` | Share secrets across tenants |
| Add a per-tenant overlay (custom skill + MCP names) | Rebuild the Docker image |
| Doctor, last logs, backup `data/` | Replace off-host backups |

Anyone who can open TMS can create and stop bots. Treat the password like a root password for this product.

**Do not** give TMS to the client’s admin (boss) agent. That person sets rules **in chat**. You add skills here.

---

## 2. Start

On the Docker host, from this repo:

```bash
TMS_PASSWORD='choose-a-long-operator-password' ./scripts/tms.sh
```

Open [http://127.0.0.1:8787](http://127.0.0.1:8787). Sign in with the same password.

| Env | Default | Meaning |
|---|---|---|
| `TMS_PASSWORD` | (required) | Sign-in password. Cookie is derived from this value. |
| `TMS_HOST` | `127.0.0.1` | Bind address. Keep localhost or a VPN interface. |
| `TMS_PORT` | `8787` | HTTP port |
| `HERMES_AGENTS_HOME` | `~/hermes-agents` | Where tenants live (must match `agent.sh`) |

Python 3 is required on the **host** (the bots themselves stay in Docker).

```bash
# Optional bind
TMS_HOST=127.0.0.1 TMS_PORT=8787 TMS_PASSWORD='…' ./scripts/tms.sh
```

**Do not** publish `8787` to the public internet (`-p 8787:8787` on a VPS, nginx without auth, etc.). If you need remote access, use SSH tunnel or VPN:

```bash
ssh -L 8787:127.0.0.1:8787 user@your-host
# then open http://127.0.0.1:8787 on your laptop
```

If `TMS_PASSWORD` is missing, the process exits immediately.

---

## 3. Sign in

1. Password field → **Sign in**.
2. A `tms` HttpOnly cookie is set (`SameSite=Strict`). There is no user database — one shared operator password.
3. **Log out** clears the cookie.

Wrong password → `bad password`. Session lost after you restart TMS with a **different** password (cookie is HMAC of the current password).

---

## 4. Screen map

After login you see four blocks plus a tenant table and an **Output** log.

### New tenant

Standalone bot (not part of a company).

1. **Name** — `a-z A-Z 0-9 _ -` only. Example: `solo-cs`.
2. **Industry pack** — `cs`, `marketing`, `admin`, `pos`, `hrms`, `engineer`.
3. **Create** — runs `agent.sh new <name> <pack>`. Creates `~/hermes-agents/<name>/data` and `.env` from `.env.example`. Does **not** start the container.

Then select the row, fill **Set secrets**, **Start**.

### Company (multi-role)

One paying client, several bots. Shared **rules + reports** only — not memory.

1. **Company** slug — example `acme`.
2. **New company** — `agent.sh company new acme` → `~/hermes-agents/companies/acme/shared/…`
3. Keep the same company name. Pick a role (`admin` = boss, `cs`, `marketing`, or any pack).
4. **Add role** — creates `acme-cs`, `acme-admin`, …, applies that pack, writes company mounts.

Each role still needs its **own** bot token and (for paying clients) its own LLM key.

The muted list under the buttons shows companies and whether each role is running.

### Set secrets (selected tenant)

Click a tenant **name** in the table first. Header shows `selected: acme-cs`.

Empty fields are skipped. Values are written only to that tenant’s `data/.env` (`chmod 600`).

| Field | Required for Telegram CS | Notes |
|---|---|---|
| `DEEPSEEK_API_KEY` | Yes | Official DeepSeek — thinking / chat |
| `OPENCODE_GO_API_KEY` | Engineer pack only | Coding worker (pi). Do not use OpenRouter |
| `TELEGRAM_BOT_TOKEN` | Yes if using Telegram | Unique per container |
| `TELEGRAM_ALLOWED_USERS` | Yes | **Numeric** user id, not `@username` |
| `SLACK_BOT_TOKEN` / `SLACK_APP_TOKEN` / `SLACK_ALLOWED_USERS` | If Slack | Socket Mode |
| `CUSTOM_MCP_URL` / `CUSTOM_MCP_TOKEN` | Overlay only | That tenant’s MCP |

After save, **Start** or **Restart** so the gateway sees new env.

### Tenant overlay (SaaS only)

Select a tenant. Custom tools that **survive pack apply**.

1. **Skill directory** — absolute path **on this host** to a folder that contains `SKILL.md`. Example: a copy of `overlays/example-http-lookup` renamed to `acme-orders`.
2. **Add skill** — `overlay add-skill`. Name must not collide with a pack skill.
3. Paste **mcp.allow.custom.yaml** (include / deny lists) → **Save custom MCP allow**.
4. **Refresh overlay** rebuilds runtime `skills/` + merged `mcp.allow.yaml`.
5. **Restart** the tenant.

Do not let the customer paste `npx` MCP URLs here. You review the skill and allowlist.

### Tenants table

| Column | Meaning |
|---|---|
| Name | Click to select (secrets + overlay target) |
| Status | `running` / `stopped` (from `docker ps`) |
| Company / role | Set if created via **Add role** |
| Pack | Industry pack; `+N overlay` if custom skills exist |
| Secrets | How many of the three Telegram-required keys are set |
| Actions | See below |

| Button | What it runs | Afterward |
|---|---|---|
| **Start** | `agent.sh up` (may take minutes the first time the image builds) | Container up |
| **Stop** | `down` | Data kept |
| **Restart** | `restart` | Reloads SOUL / skills / `.env` |
| **Apply pack** | `apply` using the pack dropdown in **New tenant** | Overlay kept; then Restart |
| **Doctor** | checks Docker, container, keys | Read Output |
| **Logs** | last ~80 lines | Read Output |
| **Backup** | tar `data/` (no caches) | Path printed in Output |

**Apply pack** uses whichever pack is selected in the **New tenant** dropdown. Confirm that dropdown before you click Apply.

### Output

Last command stdout/stderr. First place to look when Create / Start / Apply fails.

---

## 5. Typical flows

### A. One CS bot

1. New tenant `acme-cs` + pack `cs` → Create  
2. Click `acme-cs` → secrets (Go key, Telegram token, numeric user id) → Save  
3. Start → wait → Doctor  
4. DM the bot `/start`

### B. Company: admin + CS + marketing

1. Company `acme` → New company  
2. Add role `admin`, then `cs`, then `marketing`  
3. Select each row, save **different** bot tokens, Start each  
4. Boss chats with `acme-admin` to set rules  
5. CS/marketing append reports; admin asks for a briefing  

### C. Custom tool for one customer

1. Select `acme-cs`  
2. Add skill from a host path; save custom MCP yaml  
3. Save `CUSTOM_MCP_*`  
4. Restart  
5. Later, **Apply pack** `cs` again — overlay remains  

### D. Nightly backup

Click **Backup** on each role, then copy `~/hermes-agents/<name>/backups/*.tar.gz` off the box. Also copy `~/hermes-agents/companies/<co>/shared` if they use company roles.

---

## 6. Security rules

- Bind `127.0.0.1` only (default).
- Long `TMS_PASSWORD`. Changing it invalidates cookies.
- TMS operators are equivalent to people who can run `agent.sh` on the host.
- Company admin (the bot) must not have this URL or password.
- Overlay and Apply are how skills get onto a tenant. Chat cannot do that.
- Backup tarballs contain `.env`. Encrypt or lock them down.

---

## 7. What TMS will not do

- Edit `packs/` or the Dockerfile (git + image rebuild).
- Install an MCP **server** binary for you — it only writes allow names and env. You still connect the real MCP.
- Restore a tar (use CLI: `agent.sh restore` then Start).
- Rename a tenant (CLI: `agent.sh rename`).
- Message a bot or inject into another role’s memory.

---

## 8. CLI equivalents

Every button is `agent.sh`. Useful when TMS is down:

```bash
./scripts/agent.sh new acme-cs cs
./scripts/agent.sh company new acme
./scripts/agent.sh company role acme admin
./scripts/agent.sh apply acme-cs cs
./scripts/agent.sh overlay add-skill acme-cs /path/to/acme-orders
./scripts/agent.sh overlay mcp acme-cs overlays/example-mcp.allow.yaml
./scripts/agent.sh up acme-cs
./scripts/agent.sh doctor acme-cs
./scripts/agent.sh backup acme-cs
```

---

## 9. HTTP API (localhost)

Cookie `tms` required except `/api/health`, `/api/session`, `/api/login`.

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/health` | Process up |
| GET | `/api/session` | `{ ok: true }` if cookie valid |
| POST | `/api/login` | `{ password }` |
| POST | `/api/logout` | Clear cookie |
| GET | `/api/packs` | Industry packs |
| GET | `/api/tenants` | Bots + status + overlay count |
| POST | `/api/tenants` | `{ name, pack }` create |
| GET | `/api/companies` | Companies + roles |
| POST | `/api/companies` | `{ name }` |
| POST | `/api/companies/:co/roles` | `{ role }` |
| POST | `/api/tenants/:name/up\|down\|restart\|backup` | Lifecycle |
| POST | `/api/tenants/:name/apply` | `{ pack }` |
| POST | `/api/tenants/:name/secrets` | Allowlisted keys only |
| GET | `/api/tenants/:name/logs` | Tail |
| GET | `/api/tenants/:name/doctor` | Doctor text |
| GET | `/api/tenants/:name/overlay` | Custom skills + yaml |
| POST | `/api/tenants/:name/overlay/skill` | `{ source }` host dir |
| POST | `/api/tenants/:name/overlay/mcp` | `{ yaml }` or `{ source }` |
| POST | `/api/tenants/:name/overlay/refresh` | Rebuild runtime skills |

---

## 10. Troubleshooting

| Symptom | Check |
|---|---|
| Process exits at start | `TMS_PASSWORD` is set |
| Sign-in always fails | Same password as the running process; no extra spaces |
| Create fails, name invalid | Only `a-zA-Z0-9_-` |
| Start hangs a long time | First image build; watch Output / host `docker images` |
| Start: empty volume / colons | Always use TMS or `agent.sh up`, not raw compose |
| Apply did not change personality | Click **Restart** after Apply |
| Overlay skill rejected | Folder needs `SKILL.md`; id must not match a pack skill |
| Add skill path not found | Path is on the **TMS host**, not your laptop (unless they are the same machine) |
| Secrets saved but bot ignores them | Restart |
| 409 Conflict in logs | Two containers or a host gateway on the same Telegram token |
| Cannot see company roles | Created with **Add role**, not only New tenant |
| Port already in use | `TMS_PORT=8788` or stop the other process |

---

## 11. Files

```
scripts/tms.sh          launcher (requires TMS_PASSWORD)
tms/server.py           stdlib HTTP; calls agent.sh
tms/static/index.html   console UI
```

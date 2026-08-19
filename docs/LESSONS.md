# Lessons learned

Field notes from real incidents — read before operating an agent, so you don't
repeat the same mistakes.

## 1. A group chat "no response" is usually a STUCK SEARCH LOOP, not a bot outage

**Symptom:** An operator asks the bot in a Telegram group "can you link the
wedding system we built earlier" and gets nothing — for 40+ minutes.

**Root cause:** The group message opened a brand-new session (history=0) that did
not know where the project lived. Instead of asking, it spun through endless
`session_search` + `terminal` calls hunting for the system, repeatedly hitting
`Broken pipe` (API timeouts) and retrying. The reply never made it out, so it
*looked* like the bot ignored the group.

### How to avoid it
- If a group / new session asks about something "built earlier" and you don't know
  where it is, **check the real project paths first** (the shared control-plane
  repo is mounted at `/opt/repo`; its projects live under `/opt/repo/workspaces/`).
  Don't search indefinitely.
- If no response arrives for a while, **check the agent log** for a stuck session
  before concluding the bot is down:
  ```bash
  tail -f ~/.hermes/logs/agent.log          # or /opt/data/logs/agent.log
  ```

### How to stop a stuck session
```bash
hermes sessions delete <session-id> --yes
```
- The gateway **cannot restart itself from inside** (it would SIGTERM its own
  child). Run `hermes gateway restart` from a separate shell on the host.
- Deleting a session stops future delivery to that chat; memory / `state.db` on
  disk is untouched.

### One-line rule
> A fresh session doesn't know your history. Tell it where things are, or check
> `/opt/repo/workspaces/` — don't let it search forever.

## 2. `Broken pipe` (httpx.ReadError) errors = KEEP-ALIVE POOL reuse, not flaky network

**Symptom:** Logs show repeated `httpx.ReadError: [Errno 32] Broken pipe` while
calling the LLM API. Turns can *appear* stuck.

**Debugging insight (what we actually found):**
- Raw connectivity is usually **stable**: `curl -N` against the same SSE endpoint
  streams the full response with zero drops and a clean `data: [DONE]`.
- `HTTP(S)_PROXY` are often **empty** — direct connection, no proxy.
- The errors cluster at **fixed intervals** (10–27 min), each burst retries then
  goes quiet. That pattern is the signature of an **HTTP keep-alive pool reusing
  a connection the upstream (reverse proxy / cloud) already closed on its own
  idle timeout** → the write fails with EPIPE.

**Why curl is fine but Hermes isn't:** curl opens a fresh connection per request;
Hermes uses a keep-alive pool (`keepalive_expiry=20s` in
`agent/process_bootstrap.py`), so it can reuse a stale connection.

**Fixes (config-level, no shared-image edit):**
- Raise main-agent retry tolerance: `hermes config set agent.api_max_retries 5`
  (default 3).
- Raise auxiliary retries: `hermes config set auxiliary.transient_retries 4`
  (default 2).
- Keep a `fallback_providers` entry (e.g. `glm-5`) so a failing primary
  auto-switches.
- **Do NOT** "fix" this with `gateway.streaming: false` — that key is invalid
  and only affects how replies render, not the API call. A single Broken pipe is
  retryable; only stop a turn if it is genuinely stuck (see #1).

### One-line rule
> Broken pipe in bursts = stale keep-alive reuse. Raise retries in config, keep a
> fallback, and verify with `curl -N` before blaming the network.

## 3. "PermissionError: telegram-approved.json" after container ops = root wrote the mount

**Symptom:** Intermittent `Sorry, I encountered an error (PermissionError). [Errno 13]
Permission denied: '/opt/data/platforms/pairing/telegram-approved.json'` — the operator
gets marked unauthorized at random.

**Root cause:** Classic Docker ownership flip. The pairing store files under
`/opt/data/platforms/pairing/` get written by the **gateway process, which runs as
`hermes`** (uid 10000 after the gosu drop). When the operator runs `docker exec -u root`
(or `docker exec` without `-u`) and touches anything under `/opt/data` — or does the
`docker commit` / `docker run` / container-swap dance we did — the pairing files can end
up **owned by root**. The `hermes` gateway then cannot read them → `PermissionError` →
the operator is silently treated as unauthorized. (The code itself flags this: see
`gateway/pairing.py` `_load_json`, comment about the classic Docker symptom.)

**Why intermittent:** It only breaks after a root write; once re-owned by `hermes` it
works again. So it appears "sometimes," usually right after host-side container work.

### How to avoid it
- **Never write under `/opt/data` as root.** Use the hermes user:
  ```bash
  docker exec -u hermes agentA <command>
  ```
  or operate directly on the host bind-mount path (`/opt/hermes-agents/agentA/data/…`)
  as `admin`, not root.
- After any container/root operation, re-sync ownership if an error appears:
  ```bash
  chown -R hermes:hermes /opt/data/platforms
  ```

### One-line rule
> Docker root-write on a mount flips file ownership → the hermes gateway can't read
> pairing/approved files → random PermissionError. Always exec as `-u hermes` (or edit
> the host mount as `admin`), never root.


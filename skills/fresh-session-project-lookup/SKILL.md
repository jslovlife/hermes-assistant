---
name: fresh-session-project-lookup
description: Use when a new session / group chat asks about something "built earlier" or references an existing project, and you don't know where it is. Avoids the stuck-search-loop failure.
---

# Fresh-session project lookup

A **new session** (or a Telegram group thread) has **history=0** — it does NOT
know what was discussed in your DM, and it does NOT know where projects live.

## The failure this prevents

Asked "can you link the wedding system we built earlier?", a fresh session with no
context spun through endless `session_search` + `terminal` calls hunting for the
project, kept hitting `Broken pipe` timeouts, retried, and never replied for 40+
minutes. The operator saw "no response" and thought the bot was down.

## Do this instead

1. **Check the real project paths FIRST** — don't search forever.
   - Shared control-plane repo is mounted at `/opt/repo`
   - Its projects live under `/opt/repo/workspaces/`
   - Per-agent workspace: `/opt/workspaces/`
2. If you don't recognize the project, **`ls /opt/repo/workspaces/`** (or
   `search_files`) to see what exists before searching session history.
3. Only after confirming the path is unknown should you use `session_search`.
4. **Ask the operator** for the project name / path if still unclear — cheaper
   than a 40-minute search loop.

## If a turn gets stuck (no reply for a while)

- Check the log: `tail -f /opt/data/logs/agent.log`
- Stop it: `hermes sessions delete <session-id> --yes`
- The gateway can't restart itself from inside; run `hermes gateway restart`
  from a separate host shell.

## One-line rule
> A fresh session doesn't know your history. Look in `/opt/repo/workspaces/`
> first, or just ask — don't let it search forever.

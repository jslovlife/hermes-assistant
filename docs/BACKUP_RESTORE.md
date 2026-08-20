# Backup & restore — the suitcase guide

Welcome. You are about to learn the only trick that matters:

> **The container is a hotel room. The data folder is the suitcase.**
> Throw away the room whenever you like. Never lose the suitcase.

That is why deleting a Docker container feels scary and then… nothing important is gone. Skills, `.env`, memory, and personality all live on the **host disk**, not inside the image.

This guide is for first-time operators on a **MacBook** (Docker Desktop) or a **cloud VM** (Ubuntu + Docker Engine). Same commands. Same suitcase.

---

## 1. What is in the suitcase (keep this)

Host path (typical):

```text
~/hermes-agents/<name>/data/          ← THIS is the agent
```

On some servers it may be elsewhere, for example `/opt/hermes-agents/agentA/data`. `agent.sh` follows `agent.conf`; you do not have to guess.

| Inside `data/` | What it is | Survives a new container? |
|---|---|---|
| `.env` | Bot token, DeepSeek key, Go key | **Yes** — if you restore this folder |
| `skills/` + `skills-custom/` | Pack skills + your overlays | **Yes** |
| `SOUL.md` + `config.yaml` | Personality | **Yes** |
| `state.db` + `memories/` | Chat memory | **Yes** |
| `mcp.allow*.yaml` | Which tools are allowed | **Yes** |
| `.pack` | Which industry pack was applied | **Yes** |

`./scripts/agent.sh backup <name>` packs **exactly this folder** (minus caches: `home`, `lsp`, `cache`, `.npm`).

### What is *not* in that tarball

| Left behind | Why | If you care |
|---|---|---|
| `workspaces/` | Project files the agent built | Copy that folder too (optional extra tar) |
| `companies/<co>/shared/` | Company rules/reports | Copy if this agent is a **company role** |
| The Docker container | Disposable on purpose | Recreate with `up` |
| The image | Shared by every agent | Rebuild only if the Dockerfile changed |

---

## 2. First-time host setup (any environment)

You need **Docker** and **git**. You do **not** install Hermes, Node, or Python for the bot.

### MacBook

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/) and start it (whale in the menu bar).
2. Terminal:

```bash
git clone <this-repo-url> hermes-assistant
cd hermes-assistant
docker info    # must work without drama
```

### Cloud server (Ubuntu-ish)

```bash
# Docker Engine — follow Docker's current Ubuntu install, then:
sudo usermod -aG docker "$USER"
# log out and back in so `docker` works without sudo

git clone <this-repo-url> hermes-assistant
cd hermes-assistant
docker info
```

**Golden rule on Linux:** `sudo docker` is fine if your user is not in the `docker` group yet. **`sudo ./scripts/agent.sh` is not.** Running the script as root remaps the gateway to UID 0 and pairing/skills files get weird permissions. Run `agent.sh` as `admin` / `ubuntu` / yourself.

---

## 3. Pack the suitcase (backup)

From the repo, on the machine that already has the agent:

```bash
cd ~/hermes-assistant          # or wherever you cloned
./scripts/agent.sh list        # confirm the name, e.g. agentA
./scripts/agent.sh backup agentA
```

It prints a path like:

```text
/home/admin/hermes-agents/agentA/backups/agentA-20260820-210000.tar.gz
```

**Now copy that file off the machine.** A backup that only lives on the same disk as the agent is a souvenir, not a backup.

```bash
# Mac → cloud, or cloud → laptop (examples)
scp admin@your-vps:~/hermes-agents/agentA/backups/agentA-*.tar.gz ~/Desktop/

# optional: workspaces too
tar -czf agentA-workspaces.tar.gz -C "$(dirname "$(./scripts/agent.sh config agentA)")/.." workspaces
```

TMS: the **Backup** button runs the same `agent.sh backup`. Still copy the `.tar.gz` off the box.

Do this before you `docker rm`, before a disk wipe, before “I will just recreate it quickly.”

---

## 4. Same machine — I deleted the container (the usual scare)

If the **data folder is still there**, you did not lose `.env` or skills. You only lost the hotel room.

```bash
# 1. Prove the suitcase exists
ls -la ~/hermes-agents/agentA/data/.env
ls -la ~/hermes-agents/agentA/data/skills
# or, if you stored data under /opt:
ls -la /opt/hermes-agents/agentA/data/.env

# 2. Re-attach the name to that folder (does NOT copy, does NOT wipe)
./scripts/agent.sh restore agentA /opt/hermes-agents/agentA/data
# use the real path from step 1

# 3. New container, old brain
./scripts/agent.sh up agentA
./scripts/agent.sh doctor agentA
```

`restore` writes `agent.conf` and private company dirs. It does **not** overwrite `.env` or `skills/`.

If `agent.conf` already pointed at that data dir, `up` alone is enough. `restore` is the safe extra step after a messy move.

**Do not** run `agent.sh new agentA` — that command refuses if data already exists, and you do not want a second empty suitcase anyway.

**Do not** run `agent.sh apply …` after restore. Apply refreshes pack files. Memory and `.env` stay, but you can shuffle skills you did not mean to touch. Restore first; apply only when you *intend* to change the pack.

---

## 5. New machine — Mac → cloud, or cloud → new VM

Think: unpack suitcase, then check into a new hotel.

### On the new host

```bash
git clone <this-repo-url> hermes-assistant
cd hermes-assistant
docker info
```

### Unpack so you have a `data/` directory

The tarball contains a folder named `data` (the basename of the original data dir):

```bash
mkdir -p ~/hermes-agents/agentA
cd ~/hermes-agents/agentA
tar -tzf /path/to/agentA-20260820-210000.tar.gz | head   # peek: should start with data/
tar -xzf /path/to/agentA-20260820-210000.tar.gz
ls data/.env data/skills data/SOUL.md
```

If you also copied workspaces:

```bash
mkdir -p ~/hermes-agents/agentA/workspaces
tar -xzf /path/to/agentA-workspaces.tar.gz -C ~/hermes-agents/agentA
```

### Re-attach and start

```bash
cd ~/hermes-assistant
./scripts/agent.sh restore agentA ~/hermes-agents/agentA/data
./scripts/agent.sh up agentA
./scripts/agent.sh doctor agentA
./scripts/agent.sh logs agentA --once
```

`restore` will pick up `…/agentA/workspaces` automatically if that sibling folder exists.

You should **not** paste keys again. They are already in `data/.env`. If Telegram is quiet, it is usually “two containers on the same bot token” — stop the old host first.

---

## 6. The short spell (cheat sheet)

```text
backup   =  tar the data folder (suitcase)
restore  =  point a name at an existing data folder (check in)
up       =  create/start the container (hotel room)
new      =  empty suitcase for a brand-new agent   ← not for recovery
apply    =  change industry pack                   ← not for recovery
```

Same host, container gone, data still there:

```bash
./scripts/agent.sh restore <name> /path/to/data
./scripts/agent.sh up <name>
```

Data gone, but you have a `.tar.gz`:

```bash
mkdir -p ~/hermes-agents/<name> && cd ~/hermes-agents/<name>
tar -xzf /path/to/<name>-*.tar.gz
cd /path/to/hermes-assistant
./scripts/agent.sh restore <name> ~/hermes-agents/<name>/data
./scripts/agent.sh up <name>
```

---

## 7. Company roles (itcompany-admin and friends)

`backup` still only saves **that role’s** `data/` (`.env`, skills, memory).

Also copy:

```text
~/hermes-agents/companies/<company>/shared/
```

Restore each role the same way (`restore itcompany-admin …/data` then `up`). Do **not** point a restored standalone agent at another company’s `shared/` folder.

---

## 8. Please don’t

| Temptation | What actually happens |
|---|---|
| `agent.sh new` then copy `.env` by hand | Easy to miss `skills-custom/`, `state.db`, overlay |
| `apply` “just to be safe” after restore | Rewrites pack SOUL/skills; overlay is kept, but you did not need this |
| `docker compose down` in the repo directory | Can stop **other** agents on the same host |
| `sudo ./scripts/agent.sh up` | UID 0 vs hermes user → `PermissionError` on pairing files |
| Leave the only tarball on the same VPS | Disk dies, agent dies with it |
| Two `up`s on two machines, same Telegram token | 409 conflict; neither bot is happy |

`down` / `restart` in current `agent.sh` target **one container name**. They will not pack the suitcase for you — backup first if you are about to wipe a disk.

---

## 9. “Did I keep my skills and .env?” checklist

After `up`:

```bash
# .env still yours?
./scripts/agent.sh config agentA
# open that file — tokens should already be filled

# skills still yours?
ls "$(dirname "$(./scripts/agent.sh config agentA)")/skills"
ls "$(dirname "$(./scripts/agent.sh config agentA)")/skills-custom"

# container sees the same disk?
docker inspect agentA --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{println}}{{end}}'
```

You want `…/data -> /opt/data`. If `/opt/data` is an empty anonymous volume, you attached the wrong folder — `down` that container (data on host is fine), `restore` with the correct path, `up` again.

`doctor` should show `ok` for the container and keys. A `warn` about `_standalone` means an old shared company mount — standalone restores now get a **private** `company/` folder; that is expected and safe.

---

## 10. Mac vs cloud: tiny differences

| | MacBook | Cloud VM |
|---|---|---|
| Docker | Docker Desktop | Docker Engine |
| Typical data path | `~/hermes-agents/<name>/data` | same, or `/opt/hermes-agents/<name>/data` |
| `docker` without sudo | Desktop does this | add user to `docker` group |
| Sleep | Don’t. Desktop sleeps = bot sleeps | VPS stays up |
| Copy backup off | AirDrop, drive, `scp` | `scp` / object storage |

The script does not care which planet you are on. **Keep the suitcase. Recreate the room.**

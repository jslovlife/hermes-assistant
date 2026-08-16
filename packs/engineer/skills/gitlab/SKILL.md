---
name: gitlab
description: Work with GitLab (self-hosted or gitlab.com): SSH/git auth, clone/push, merge requests via REST.
version: 1.0.0
metadata:
  hermes:
    tags: [gitlab, git, self-hosted, gitops]
    category: devops
    requires_toolsets: [terminal]
---

# GitLab

Work with GitLab repositories — usually **self-hosted** (not gitlab.com).

## Credentials (per-deployment, never committed)

1. **SSH key** — for `git clone` / `git push`.
2. **Personal Access Token** — for the REST API (issues, merge requests, CI).

## Setup

### SSH key

```bash
ssh-keygen -t ed25519 -f ~/.ssh/gitlab_ed25519 -N "" -C "hermes-agent-gitlab"
```

Add the `.pub` file to GitLab → **Settings → SSH Keys**.

SSH host entry — **replace `gitlab.example.com` with the real self-hosted host**:

```
Host gitlab.example.com
  HostName gitlab.example.com
  User git
  IdentityFile ~/.ssh/gitlab_ed25519
  IdentitiesOnly yes
```

HTTPS → SSH rewriting:

```bash
git config --global url."git@gitlab.example.com:".insteadOf "https://gitlab.example.com/"
```

### Token (REST API)

In `.env`:

```
GITLAB_URL=https://gitlab.example.com   # self-hosted base URL (omit for gitlab.com)
GITLAB_TOKEN=glpat-xxxx                  # PAT; scopes: api, read_repository, write_repository
```

## Common operations

- Clone: `git clone git@gitlab.example.com:group/project.git`
- Push: `git push origin main`
- Open a merge request:

```bash
curl --request POST \
  --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "$GITLAB_URL/api/v4/projects/:id/merge_requests" \
  --data "source_branch=feat-x&target_branch=main&title=..."
```

## Notes

- **Always honor `GITLAB_URL`** — most GitLab here is self-hosted; never assume gitlab.com.
- Token lives in `.env` (gitignored). Never paste it into chat.

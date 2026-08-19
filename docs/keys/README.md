# Keys & Secrets — 配置指南

每个 agent 通过它自己的 `.env`（`agent.sh config <name>` 可拿到路径）配置密钥。`.env` 永不提交进 git。

## 必备密钥（按 agent 的角色）

| 变量 | 用途 | 从哪获取 | 文档 |
|---|---|---|---|
| `DEEPSEEK_API_KEY` | 思考/推理模型 | DeepSeek 开放平台 | [deepseek.md](deepseek.md) |
| `TELEGRAM_BOT_TOKEN` | Telegram 频道 | @BotFather | [telegram.md](telegram.md) |
| `TELEGRAM_ALLOWED_USERS` | 谁有权限操作 | @userinfobot | [telegram.md](telegram.md) |

## 按需密钥（取决于 agent 的包/功能）

| 变量 | 用途 | 从哪获取 | 文档 |
|---|---|---|---|
| `OPENCODE_GO_API_KEY` | 编码 worker（pi-agent）| OpenCode Go | [opencode-go.md](opencode-go.md) |
| `SLACK_BOT_TOKEN` / `SLACK_APP_TOKEN` / `SLACK_ALLOWED_USERS` | Slack 频道（Socket Mode）| api.slack.com | [slack.md](slack.md) |
| `GITHUB_TOKEN` / `GITHUB_USER` | 让 agent 建/推 GitHub repo | GitHub tokens | [github.md](github.md) |
| `TMS_PASSWORD` | 操作者 Web 控制台 | 你自己设 | 见 [TMS.md](../TMS.md) |

## 标准配置流程（新用户）

1. 按上面「必备密钥」先把 `DEEPSEEK_API_KEY` + Telegram 那两项拿齐（各对应一份 md）。
2. 建 agent：`./scripts/agent.sh new my-bot`（或加 `--soul` / 包）。
3. 打开 `.env`：`open "$(./scripts/agent.sh config my-bot)"`。
4. 把拿到的 key 填进对应变量。
5. 启动并体检：`./scripts/agent.sh up my-bot` → `./scripts/agent.sh doctor my-bot`。
6. `doctor` 显示 `FAIL` 的项就是还没配好/配错的。

> 提示：如果用的是编码类包（`engineer`），还要配 `OPENCODE_GO_API_KEY`；用 Slack 就配 Slack 那三项。

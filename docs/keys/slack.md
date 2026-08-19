# Slack 配置（Socket Mode）

可选频道，适合办公场景（POS / HRMS / 内部协作）。用 **Socket Mode**，无需公网 URL。

## 获取步骤

1. 打开 https://api.slack.com/apps → **Create New App** → **From scratch**。
2. 填名字 + 选 workspace → Create。
3. 左侧 **Socket Mode** → **Enable Socket Mode**（创建时给个 `app_token_scope`）。
4. 左侧 **Bot Tokens** / **OAuth & Permissions**：
   - 添加 bot 需要的 scope（如 `chat:write`、`app_mentions:read`）。
   - **Install to Workspace** → 授权 → 得到 **Bot Token**（`xoxb-...`）。
5. 左侧 **App-Level Tokens**（Basic Information 里）→ 得到 **App Token**（`xapp-...`）。
6. 填进 `.env`：
   ```
   SLACK_BOT_TOKEN=xoxb-...
   SLACK_APP_TOKEN=xapp-...
   # 允许用户 = 成员 ID（在 workspace 里点开某个成员，从 URL 拿 ID）
   # SLACK_ALLOWED_USERS=U0123456789
   ```

## 注意事项

- 必须**同时**有 `xoxb-`（bot）和 `xapp-`（app）两个 token，Socket Mode 才能跑。
- 只在 `.env` 填，绝不提交 git / 贴聊天。
- 重启生效：`agent.sh restart <name>`。

## 验证

`agent.sh doctor <name>` 应显示 `ok SLACK_BOT_TOKEN`；把 bot 加进 workspace 并 @它，能回复即生效。

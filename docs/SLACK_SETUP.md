# Slack 接入指南（Socket Mode）

本文档教你在**任何一台电脑**上手动启用 Hermes 的 Slack 集成。配置一次，Clone 仓库后每台新电脑都能复用（token 不同）。

## 原理

- Hermes 通过 **Socket Mode** 连接 Slack —— **只出站、不需要公网端口**（和 Telegram 长轮询一样，适合 VPS/内网）。
- Slack 适配器是纯环境变量驱动的：只要 `.env` 里有 `SLACK_BOT_TOKEN` + `SLACK_APP_TOKEN`，重启 gateway 即自动启用。**不需要改 config.yaml**。
- 一个 Slack App 对应一个 Hermes 实例。**不要**在两个容器上用同一个 Bot Token（会冲突）。

## 一、创建 Slack App（约 5 分钟，浏览器操作）

### 1. 打开控制台
访问 https://api.slack.com/apps → **Create New App** → **From scratch**

### 2. 填写信息
- **App Name**：例如 `NewMa`
- **Pick a workspace**：选择你的 Slack 工作区
- 点 **Create App**

### 3. 生成 App-Level Token（`xapp-...`）
1. 左侧菜单 → **App-Level Tokens** → **Generate Token and Scopes**
2. Token Name 随意（如 `socket-mode`）
3. **Scope**：勾选 **`connections:write`**（唯一必需）
4. 点 **Generate** → 复制 `xapp-...` token

### 4. 添加 Bot Token 需要的权限（`xoxb-...`）
1. 左侧菜单 → **OAuth & Permissions** → **Scopes** 区域
2. 在 **Bot Token Scopes** 点 **Add an OAuth Scope**，添加：
   - `chat:write` — 发送消息
   - `channels:read` — 读取公开频道
   - `groups:read` — 读取私群
   - `channels:history` — 读公开频道历史
   - `groups:history` — 读私群历史
   - `im:history` — 读私聊历史
   - `mpim:history` — 读多人私聊历史（**群聊必须**）
   - `mpim:read` — 读多人私聊基本信息（**群聊必须**）
   - `app_mentions:read` — 接收 @提及
   - （可选）`reactions:write` — 加表情
3. 点上方 **Install to Workspace** → **Allow** 授权
4. 得到 **Bot User OAuth Token（`xoxb-...`）**

### 4b. 配置事件订阅（⚠️ 必做，否则 bot 收不到消息）
1. 左侧菜单 → **Event Subscriptions** → 打开 **Enable Events**
2. 在 **Subscribe to bot events** → **Add Bot User Event**，添加：
   - `message.channels` — 公开频道消息
   - `message.groups` — 私群消息
   - `message.im` — 私聊消息
   - `message.mpim` — **多人私聊消息（群聊必须）**
   - `app_mention` — @提及
3. 点 **Save Changes**
4. **改过 scope 或事件后必须 Reinstall**：OAuth & Permissions → **Reinstall to Workspace**

> ⚠️ 没有事件订阅，bot **收不到任何消息**（日志里看不到 inbound message）。这是最常见的"bot 没反应"原因。

### 5.（可选）允许任意用户触发
默认只响应白名单用户。若你想让所有成员都能用（内部工具场景），可忽略；否则保留白名单即可。

## 二、配置到 Hermes

### 方式 A：单机 `.env`（最直接）

编辑 `~/.hermes/.env`（或在 Docker 的 `/opt/data/.env`）添加：

```bash
# Slack
SLACK_BOT_TOKEN=xoxb-你的bot令牌
SLACK_APP_TOKEN=xapp-你的app令牌
# 允许的 Slack 成员 ID（逗号分隔，U 开头）。不填则默认只响应安装者。
# 获取：成员资料 → ⋯ → Copy member ID
SLACK_ALLOWED_USERS=U0123456789
```

### 方式 B：本仓库多 agent 流程（推荐）

仓库的 `.env.example` 已包含 Slack 模板。按 `agent.sh` 流程：

1. 复制模板：`cp .env.example .env`
2. 填入 `SLACK_BOT_TOKEN`、`SLACK_APP_TOKEN`、`SLACK_ALLOWED_USERS`
3. 用 `agent.sh` 启动/更新 agent：
   ```bash
   ./scripts/agent.sh up <agent名>
   ```
4. 重启生效（配置在 agent 的 `.env` 里，seeder 不会覆盖）

## 三、重启并验证

### 1. 重启 gateway

本地：
```bash
hermes gateway restart
```

Docker（agent.sh 流程）：
```bash
./scripts/agent.sh restart <agent名>
```

### 2. 验证启用

看日志确认 Slack 已连接：
```bash
grep -iE "slack" ~/.hermes/logs/gateway.log
# 期望看到类似 "[Slack] connected" / "Socket Mode ... started"
```

### 3. 测试

在 Slack 里：
- **私聊**：直接给 bot 发消息
- **频道**：把 bot 加进频道，然后 **@NewMa** 触发

## 三.b 让指定频道免 @（可选）

默认：**公开频道 / 私群必须 @bot 才回复**；私聊 / 多人私聊**不用 @**。

若想让**特定频道**不用 @ 就自动回复，用 `free_response_channels`：

1. 拿到频道 ID（`C...` 开头）：频道名 → 右键 → Copy link → URL 里的 `C0BQR2M3D42`；或发一条消息后 `grep 'slack:group' ~/.hermes/sessions/sessions.json`
2. 设置配置：
   ```bash
   hermes config set platforms.slack.extra.free_response_channels C0BQR2M3D42
   ```
   多个用逗号分隔：`hermes config set platforms.slack.extra.free_response_channels "C1,C2"`
3. 重启 gateway 生效（见第三节）

## 四、常见问题

| 现象 | 原因 / 解决 |
|---|---|
| 日志报 `SLACK_BOT_TOKEN not set` | `.env` 没填对，或没重启 gateway |
| 报 `SLACK_APP_TOKEN not set` | App-Level Token 没生成，或没加 `connections:write` scope |
| Bot 在频道不回复 | 需要 **@提及** 触发（或设置 `SLACK_ALLOW_ALL_USERS`）；确认 bot 已加入该频道 |
| 报权限不足 (missing_scope) | Bot Token 缺对应 scope，回 OAuth & Permissions 补 |
| 两个容器冲突 | 同一 Bot Token 被多个实例使用 —— 每个容器用独立的 Slack App |
| 只回安装者、别人不理 | 白名单限制 —— 加 `SLACK_ALLOWED_USERS` 或启用 `SLACK_ALLOW_ALL_USERS` |

## 五、与 Telegram 共存

- Telegram 和 Slack 可以**同时启用**，各自独立 token、独立白名单。
- 会话按平台/频道隔离（除非用 `/resume` 切换）。
- 同一个 Hermes 实例可同时监听多个平台。

## 安全提醒

- Token 是敏感凭证，只放进 `.env`（已被 `.gitignore` 忽略），**绝不提交到仓库或发到聊天**。
- `SLACK_APP_TOKEN` 只用于建立 Socket 连接；实际 API 调用用的是 `SLACK_BOT_TOKEN`。

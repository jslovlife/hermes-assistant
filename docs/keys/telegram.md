# Telegram 配置（bot + 允许用户）

默认消息频道是 Telegram。需要两个东西：**bot token**（`TELEGRAM_BOT_TOKEN`）和**你的数字用户 ID**（`TELEGRAM_ALLOWED_USERS`）。

## 1. 创建 bot，拿 token

1. 在 Telegram 搜索 **@BotFather**（官方机器人）。
2. 发送 `/newbot`，按提示给 bot 起名和用户名（username 必须以 `bot` 结尾）。
3. BotFather 会返回一个 **token**（形如 `123456789:AAF...`）。**复制它**。
4. 填进 `.env`：
   ```
   TELEGRAM_BOT_TOKEN=123456789:AAF...
   ```

## 2. 拿你自己的数字 ID（允许用户）

1. 搜索 **@userinfobot**（信息机器人）。
2. 对它发送 `/start`，它会回你的**数字 ID**（纯数字）。
3. 填进 `.env`：
   ```
   TELEGRAM_ALLOWED_USERS=你的数字ID
   ```
   > 注意：必须是**数字 ID**，不是 bot 用户名。

## 3.（可选）允许某个群聊

把 **@userinfobot** 拉进那个群，让它报告群 ID，然后：
```
# 取消注释并填群 ID
# TELEGRAM_GROUP_ALLOWED_CHATS=-1001234567890
```

## 常见问题

- **bot 不回话**：token 是否填对？`TELEGRAM_ALLOWED_USERS` 是否是你自己的数字 ID？改完 `.env` 后记得 `agent.sh restart <name>`。
- **想换 bot**：给 @BotFather `/revoke` 或建新 bot，改 `.env`，`restart`。
- **doctor 报 FAIL**：说明这些 key 没配好，逐项核对。

## 验证

`agent.sh doctor <name>` 应显示 `ok TELEGRAM_BOT_TOKEN`；私聊你的 bot 能收到回复即生效。

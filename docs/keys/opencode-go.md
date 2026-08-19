# OpenCode Go Key

用于**编码 worker（pi-agent）**。只有当你给 agent 用了编码类包（如 `engineer`）时才需要。

## 获取步骤

1. 打开 https://opencode.ai/auth 并登录。
2. 进入 **Workspace keys**（工作区密钥）页面。
3. 创建一个 workspace key，复制它。
4. 在 agent 的 `.env` 里填入：
   ```
   OPENCODE_GO_API_KEY=你复制的key
   ```

## 注意事项

- 非编码类包（如 `cs`、`devops`、`qa`、`security`、`pm`、`cto`）**不需要**这个 key。
- 只在 `.env` 里填，绝不提交进 git / 贴进聊天。
- 换 key：删旧建新 → 改 `.env` → `agent.sh restart <name>`。

## 验证

用 `engineer` 包时 `doctor` 应显示 `ok OPENCODE_GO_API_KEY`；让 agent 写一段代码能成功即生效。

# GitHub Token

可选。让 agent 能**创建 / 推送 GitHub 仓库**（通过 gh CLI / API）。

## 获取步骤

1. 打开 https://github.com/settings/tokens → **Generate new token**。
2. 二选一：
   - **Classic token**：勾选 `repo` scope。
   - **Fine-grained token**：给要管理的 repo 授权 **Contents: read & write**。
3. 复制 token，填进 `.env`：
   ```
   GITHUB_TOKEN=你的token
   # GITHUB_USER=你的GitHub用户名   # agent 建 repo 时用它
   ```
4. 重启生效：`agent.sh restart <name>`。

## 注意事项

- 不想让 agent 碰 GitHub 就**留空**。
- 只在 `.env` 填，绝不提交 git / 贴聊天。
- 权限给最小够用的范围。

## 验证

`agent.sh doctor <name>` 显示 `ok GITHUB_TOKEN`；让 agent `gh repo create` 成功即生效。

# DeepSeek API Key

用于 agent 的**思考/推理模型**（默认模型，必配）。

## 获取步骤

1. 打开 https://platform.deepseek.com 并登录（没有就注册）。
2. 左侧 **API Keys** → **Create new API key**（创建前需充值 PAYG）。
3. 复制生成的 `sk-...` 密钥（**只会完整显示一次**，复制后存好）。
4. 在 agent 的 `.env` 里填入：
   ```
   DEEPSEEK_API_KEY=sk-你复制的key
   ```

## 注意事项

- 这是 **PAYG** 计费，需先充值少量余额才能调用。
- 密钥是敏感信息：**只填进 `.env`，绝不贴进聊天/提交进 git**。
- 轮换：在平台删旧 key、建新 key → 改 `.env` → `agent.sh restart <name>`。

## 验证

`agent.sh doctor <name>` 应显示 `ok DEEPSEEK_API_KEY`；agent 能正常回复即生效。

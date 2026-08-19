# souls/ — 可复用的 agent 灵魂（persona）

`souls/` 是**可选择的独立人格模板**。它只定义「这个 agent 是谁、怎么工作」，不含行业配置或技能。

## soul vs pack

| | soul | pack |
|---|---|---|
| 内容 | 只有 `SOUL.md`（人格） | `SOUL.md` + `config.yaml` + `skills/` + `mcp.allow.yaml`（完整角色包）|
| 用途 | 快速定个性，不绑定行业工具 | 完整行业角色（客服/市场/工程…）|
| 选择方式 | `agent.sh new <name> --soul <soul>` | `agent.sh new <name> <pack>` |

**怎么选：**
- 只要一个中性的通用助手 → `agent.sh new <name>`（默认）或 `--soul general`
- 只要工程人格、不整套行业工具 → `agent.sh new <name> --soul engineer`
- 要完整行业角色（带技能/配置）→ `agent.sh new <name> <pack>`（如 `cs`、`engineer`）

> 说明：`souls/general` 与默认 `config/SOUL.md` 内容一致（中立兜底）；`souls/engineer` 与 `packs/engineer/SOUL.md` 一致。这里放的是**选择菜单**，pack 仍保持自包含。

## 现有 souls

| soul | 人格 |
|---|---|
| `general` | 通用助手（中立、安全、简洁）— 默认 |
| `engineer` | 软件工程 agent（规划 + pi-agent 编码 + 门禁部署）|

## 怎么加一个 soul

```
souls/<name>/SOUL.md     # 人格（markdown，第一行 # 标题）
```
创建后即可 `agent.sh new <name> --soul <soul>` 使用。

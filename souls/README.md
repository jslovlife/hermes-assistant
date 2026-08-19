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
| `omni` | 全能技术助手（一顶全队：工程/DevOps/QA/安全/PM/CTO，按需加载技能）|
| `engineer` | 软件工程 agent（规划 + pi-agent 编码 + 门禁部署）|
| `devops` | DevOps / SRE（部署、监控、CI/CD、容器、可靠性）|
| `qa` | 测试工程师（测试策略、自动化、缺陷、发布把关）|
| `security` | 安全工程师（安全评审、漏洞、最小权限、事件）|
| `pm` | IT 项目经理 / Scrum（排期、协调、风险、交付）|
| `cto` | CTO / 技术负责人（架构方向、标准、技术取舍）|

> **两种用法：**
> - **一个人用全能助手** → `agent.sh new <name> --soul omni`。一个 agent 顶全队，需要哪个领域就加载对应技能（见 `skills/`：devops、qa、security、pm、cto）。
> - **组多角色团队** → 每个 agent 各配专业灵魂（`--soul engineer|devops|qa|security|pm|cto`），并行 + 隔离。
>
> 灵魂只定义人格；**能力在 `skills/`**（工程 + devops/qa/security/pm/cto），按需 `skill_view` 加载，不会让一个灵魂变臃肿。

## 怎么加一个 soul

```
souls/<name>/SOUL.md     # 人格（markdown，第一行 # 标题）
```
创建后即可 `agent.sh new <name> --soul <soul>` 使用。

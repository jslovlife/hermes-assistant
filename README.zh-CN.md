# Hermes Assistant（Docker）

多 agent 的 Hermes 消息助手。一个镜像、多个相互隔离的 agent —— 每个有独立的数据、bot token、人格（灵魂 soul）和可选的完整角色（包 pack）。专为「一个公司/团队要多个专职、隔离的助手」而设计。

**文档：** [用户指南](docs/USER_GUIDE.md) · [架构](docs/ARCHITECTURE.md) · [TMS](docs/TMS.md) · English: [README.md](README.md)

> **宿主机只需要 Docker + git。** bot 本身无需安装 Hermes/Node/Python。可选 Python 3 跑 TMS 控制台。

---

## 1. 如何开始（快速上手）

### 1.0 开始之前：先拿密钥

每个 agent 在能跟你对话**之前**，至少需要这几项。每项都有自己的配置文档：

| 密钥 | 用途 | 从哪获取 | 文档 |
|---|---|---|---|
| `DEEPSEEK_API_KEY` | 思考/推理模型 | platform.deepseek.com | [keys/deepseek.md](docs/keys/deepseek.md) |
| `TELEGRAM_BOT_TOKEN` | Telegram 频道 | @BotFather | [keys/telegram.md](docs/keys/telegram.md) |
| `TELEGRAM_ALLOWED_USERS` | 谁有权限操作 bot | @userinfobot | [keys/telegram.md](docs/keys/telegram.md) |
| `OPENCODE_GO_API_KEY` | 编码 worker（仅 `engineer` 包）| opencode.ai/auth | [keys/opencode-go.md](docs/keys/opencode-go.md) |
| Slack / GitHub / TMS | 可选 | — | [keys/README.md](docs/keys/README.md) |

> 每个密钥的完整教程：**[docs/keys/README.md](docs/keys/README.md)**。密钥只填 `.env`，绝不进 git / 聊天。

### 1.1 克隆、建 agent、并配置

```bash
git clone <本仓库地址> assistant
cd assistant

# 1. 建 agent，选人格：
./scripts/agent.sh new my-bot                 # 中性通用助手（默认）
./scripts/agent.sh new my-bot --soul engineer # 独立工程人格
./scripts/agent.sh new my-bot cs              # 完整角色包（客服）

# 2. 打开该 agent 的 .env，填进第 1.0 步拿到的密钥：
open "$(./scripts/agent.sh config my-bot)"
#    -> 填 DEEPSEEK_API_KEY、TELEGRAM_BOT_TOKEN、TELEGRAM_ALLOWED_USERS
#       （选了 engineer 包就还要填 OPENCODE_GO_API_KEY）

# 3. 启动，然后体检：
./scripts/agent.sh up my-bot
./scripts/agent.sh doctor my-bot     # 每行都应是 "ok"；FAIL = 那个 key 没配好
```

`config` 打印的 `.env` 路径，用来填：
- `DEEPSEEK_API_KEY` —— 思考模型 key（[deepseek.md](docs/keys/deepseek.md)）。
- `TELEGRAM_BOT_TOKEN` / `TELEGRAM_ALLOWED_USERS` —— 消息频道（[telegram.md](docs/keys/telegram.md)）。
- `OPENCODE_GO_API_KEY` —— 仅当你选了编码类包（`engineer`）时（[opencode-go.md](docs/keys/opencode-go.md)）。

如果 `doctor` 对某个 key 报 `FAIL`，去拿/修好那个 key，然后 `./scripts/agent.sh restart my-bot`。

### 1.2 查看有哪些可用

```bash
./scripts/agent.sh list     # 所有 agent + 运行状态 + 用的包
./scripts/agent.sh packs    # 所有角色包
```

### 1.3 操作者控制台（可选，仅本机）

```bash
TMS_PASSWORD='设置一个长操作者密码' ./scripts/tms.sh
# http://127.0.0.1:8787
```

---

## 2. 灵魂 vs 包（人格 vs 完整角色）

| | 灵魂 Soul | 包 Pack |
|---|---|---|
| 内容 | 只有 `SOUL.md`（人格）| `SOUL.md` + 配置 + 技能 + MCP 白名单 + 必需环境变量 |
| 命令 | `new <name> --soul <soul>` | `new <name> <pack>` |
| 例子 | `general`、`omni`、`engineer`、`devops`、`qa`、`security`、`pm`、`cto` | `cs`、`engineer`、`devops`、`qa`、`security`、`pm`、`cto`、`admin`、`marketing`、`pos`、`hrms` |
| 技能来源 | 共享 `skills/`（按需加载）| 自己的 `packs/<pack>/skills/` |

- **灵魂** = 只换人格；能力来自共享 `skills/` 库（按需 `skill_view` 加载，保持轻量）。
- **包** = 自包含、可一键部署的完整角色（人格 + 技能 + 配置 + MCP + 必需环境变量）。最适合「可复现的一次性 setup」。
- **`omni` 灵魂** = 一个 agent 同时扮演工程 / DevOps / QA / 安全 / PM / CTO，需要哪个领域就加载对应技能 —— 适合「一个人、一顶全队帽子」。

---

## 3. 公司、角色与隔离

建一家公司，把角色 agent 塞进去；**不属于这家公司的 agent 对它的数据零权限**。

```bash
# 1. 建公司（生成共享 rules/ + reports/）
./scripts/agent.sh company new acme

# 2. 塞角色 agent（每个一个 bot token）
./scripts/agent.sh company role acme admin     # 老板：可写 rules + 看全部 reports
./scripts/agent.sh company role acme devops
./scripts/agent.sh company role acme qa
./scripts/agent.sh company role acme security

# 3. 启动
./scripts/agent.sh up acme-admin
./scripts/agent.sh up acme-devops
```

**权限矩阵**（由「容器挂载 + 文件权限 + Hermes 写安全根」三层强制）：

| Agent | 公司的 `rules/` | 公司的 `reports/` |
|---|---|---|
| `<co>-admin` | 读+写 | 读全部 + 写 |
| `<co>-<role>`（如 devops）| 只读 | 只能写自己的 `reports/<role>/` |
| 另一家公司的 agent | ❌ 无挂载 | ❌ 无挂载 |
| 独立（无公司）agent | ❌ 无挂载 | ❌ 无挂载 |

隔离是**物理级**的：公司目录只挂载进该公司自己的 agent 容器，无关 agent 连看都看不到。

> **必须坦白：** 这种隔离是 agent/公司之间的隔离。**宿主机操作者（root）仍能读所有 volume**——这是 SaaS 的正常形态。要连机器拥有者都隔离，用「每公司一台 VM / on-prem」（同一镜像）。

---

## 4. 日常维护

### 4.1 修改某个 agent 的 `.env`（如轮换 bot token / API key）

```bash
# 1. 找到 .env 路径
./scripts/agent.sh config my-bot          # 打印: /path/to/~/hermes-agents/my-bot/data/.env

# 2. 编辑它
vim "$(./scripts/agent.sh config my-bot)"

# 3. 生效：重启容器，让 Hermes 重新加载新密钥
./scripts/agent.sh restart my-bot
```

`.env` **永不提交进 git**，只存在该 agent 的数据目录里。

### 4.2 重启 / 停止 / 启动 / 状态

```bash
./scripts/agent.sh restart my-bot   # 停+启（保留数据）
./scripts/agent.sh down  my-bot     # 停止容器（保留数据）
./scripts/agent.sh up    my-bot     # 重新启动
./scripts/agent.sh status my-bot    # 是否在运行？
./scripts/agent.sh logs  my-bot     # 看日志
./scripts/agent.sh list             # 所有 agent + 状态
```

### 4.3 给运行中的 agent 换角色（包）

```bash
./scripts/agent.sh apply my-bot devops   # 换包；保留 .env、记忆、overlay
./scripts/agent.sh restart my-bot        # 重新加载 SOUL/config
```

### 4.4 备份 / 恢复

```bash
./scripts/agent.sh backup my-bot     # -> ~/hermes-agents/my-bot/backups/my-bot-<时间>.tar.gz
```
备份含 `.env`、记忆、state.db、技能、overlay。请把 tarball 拷离宿主机。

---

## 5. 恢复 —— agent 挂了，Telegram/Slack 联系不上它

> **核心原则：管理一个挂掉的 agent 要在宿主机的终端做，不是通过它的聊天。** 如果 bot 在 Telegram/Slack 上不回话，那是宿主机侧的问题——在机器上修，不是在聊天里修。

### 5.1 诊断

```bash
./scripts/agent.sh status my-bot   # 容器还在吗？
./scripts/agent.sh logs  my-bot    # 报什么错？
./scripts/agent.sh doctor my-bot   # 体检：Docker、容器、密钥
```
`doctor` 会逐个输出 `ok`/`FAIL`：Docker 守护进程、数据目录、容器是否在跑、`.env` 里必需的 key。

### 5.2 按严重程度修复

| 症状 | 修复 |
|---|---|
| 容器崩了，数据还在 | `./scripts/agent.sh restart my-bot` |
| 起不来，token/key 看着不对 | `config my-bot` → 改 `.env` → `restart` |
| token 被撤销 / bot 被删 | 重新建 token，改 `.env`，`restart` |
| 容器没了但数据目录还在 | `./scripts/agent.sh restore my-bot <data-dir>` 再 `up` —— 记忆/state/.env 是重新挂接，不是重建 |
| 数据丢了 | 解压 `backup` 的 tarball，`restore`，再 `up` |
| seeder / Dockerfile 变了 | `./scripts/agent.sh down` → 重建镜像 → `up` |
| 还是起不来 | `logs my-bot` 看真实报错，检查频道 token / 网络（Telegram 只出站）|

### 5.3 恢复阶梯（聊天全不回时）

1. **宿主机检查**：`status` → `logs` → `doctor`。
2. **软重启**：`restart`。
3. **改配置**：核对/编辑 `.env`（token、允许用户），`restart`。
4. **重新挂接数据**：容器没了但数据目录在 → `restore <name> <data-dir>` → `up`。
5. **从备份恢复**：数据丢了 → 解压最新 tarball → `restore` → `up`。
6. **重建镜像**：配置看起来都对还起不来 → 重建镜像（seeder/Dockerfile 改动需要重建）。

> **经验法则：容器是可丢弃的，数据目录不是。** 只要保住数据目录（和备份），agent 的记忆几乎不会丢。

---

## 6. 架构速览

- 一个共享镜像；每个 agent = 独立容器 + 数据目录 + 工作区 + bot token。
- 容器内路径都是中性的：`/opt/repo`（只读模板）、`/opt/data`（agent 数据）、`/opt/workspaces`（agent 文件）、`/opt/company/`（公司 rules/reports，按需挂载）。
- 不挂 `docker.sock`、无特权，资源限制（默认 4 GB / 2 CPU / 256 PIDs）。
- 写安全根（`WRITE_SAFE_ROOT`）限制每个 agent 能写什么。

详见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) 和 [docs/USER_GUIDE.md](docs/USER_GUIDE.md)。

## 7. 常用命令速查

| 命令 | 用途 |
|---|---|
| `new <name> [pack\|--soul <soul>]` | 建 agent |
| `apply <name> <pack>` | 给运行中的 agent 换包（保留 `.env`/记忆/overlay）|
| `up / down / restart <name>` | 生命周期 |
| `logs / status / doctor <name>` | 检查 |
| `config <name>` | 打印 `.env` 路径 |
| `backup / restore <name>` | 数据备份 / 重新挂接 |
| `company new/role/list` | 多角色公司搭建 |
| `overlay add-skill/rm-skill/mcp` | 每个 agent 的自定义工具 |
| `rename <old> <new>` | 重命名 agent（移动数据、保留记忆）|
| `tms.sh` | Web 控制台（需 `TMS_PASSWORD`）|

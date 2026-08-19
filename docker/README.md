# docker/ — 镜像与编排

单个共享镜像 + 一份 compose，跑所有 agent（每个 agent 一个独立容器 + 数据目录）。

| 文件 | 作用 |
|---|---|
| `Dockerfile` | 在官方 `hermes-agent:base` 之上装 `pi-agent`（编码 worker），并挂载启动 seeder |
| `compose.yml` | 唯一的编排文件。一个 service `gateway`，由 `scripts/agent.sh` 通过 env 注入每个 agent 的名字/路径/密钥 |
| `05-agent-config` | 首次启动的 seeder：把 repo 里的 pack/config/skills 复制进该 agent 的 `/opt/data`（`.agent-init-done` 防重复；永不覆盖 `.env`） |

> 路径都是中性的：容器内固定 `/opt/repo`（只读共享模板）、`/opt/data`（该 agent 数据）、`/opt/workspaces`（该 agent 项目文件）、`/opt/company/`（多角色公司的共享 rules/reports）。宿主真实路径由 `agent.sh` 在运行时映射进来。

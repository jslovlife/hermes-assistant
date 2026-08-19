# skills/ — 基础技能层

`skills/` 是**默认（无 pack）agent** 的基础技能集。启动 seeder（`docker/05-agent-config`）只在 agent 没选行业包（pack）时，才把 `skills/` 复制进该 agent。

## 与 `packs/<role>/skills/` 的关系

- `skills/` = 默认 agent 的通用/工程基础技能。
- `packs/<role>/skills/` = 该角色包的专属技能，**自包含**（包单独用也能工作）。

> `gated-deploy`、`gitlab`、`mcp-proposer`、`pi-coder` 同时出现在 `skills/` 和 `packs/engineer/skills/`，**这是刻意为之，不是重复**：
> - 默认 agent（无 pack，通常是工程助手）需要它们 → 来自 `skills/`。
> - engineer 包要自包含、单独也能给 agent 完整能力 → 自带副本。
>
> **不要删除任一侧**。删 `skills/` 里会让默认 agent 丢失工程能力；删 engineer 包里的会让 engineer agent 拿到不完整的技能。

## 新增/修改技能的原则

- **想给所有默认 agent 加技能** → 放进 `skills/`。
- **只给某个行业角色加技能** → 放进 `packs/<role>/skills/`。
- **两类都需要的工程技能** → 两处都放（保持同步），或考虑把该技能抽成共享引用。

## 说明文档（本文件）会随 repo 一起提交

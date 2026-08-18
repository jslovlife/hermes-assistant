# DeepSeek Token 成本实验结论（中文 vs 英文）

## 实测数据（DeepSeek API 返回的 prompt_tokens，2026-08）

| 语言 | 字符数 | Token 数 | 每字符 token |
|---|---|---|---|
| English | 100 | 22 | **0.22** |
| Chinese | 27 | 19 | **0.70** |

## 结论

- **英文**：每字符约 **0.2 token**（比官网估的 0.3 更省）
- **中文**：每字符约 **0.7 token**（比官网估的 0.6 更多）
- **中文 ≈ 英文的 3~3.5 倍 token 消耗**

## 与官网估算对比

| 来源 | English tok/char | Chinese tok/char |
|---|---|---|
| DeepSeek 官网 | ~0.3 | ~0.6 |
| **DeepSeek 实测** | **0.22** | **0.70** |
| tiktoken(GPT风格) | 0.21 | 1.29 |

## 测试脚本

- `/opt/workspaces/token_test.py` — tiktoken 本地估算
- `/opt/workspaces/deepseek_token_test.py` — DeepSeek API 实测（最准）

## 关键洞察

1. DeepSeek 对中文的 tokenizer 比 GPT 更高效（0.70 vs 1.29）
2. 但中文仍是英文的 ~3 倍
3. 同一语义内容，用中文 prompt 成本约为英文的 3 倍

---

# 附录：禁用不需要的 Skill 省固定 token

每次对话都带**系统提示里的 skill 列表**（每个 skill 的名称 + 描述都注入）。用不到的 skill 会白白消耗固定的"入场费" token。

## 当前环境状态（2026-08）

- **系统提示 skill 总数**：90 → 75（禁用 15 个不需要的）
- **节省**：约 627 字符描述 / 每轮约 130-140 token

## 已禁用的 15 个（确定不用）

| 分类 | Skills |
|---|---|
| apple | apple-notes, apple-reminders, findmy, imessage |
| smart-home | openhue |
| mlops | huggingface-hub, evaluating-llms-harness, weights-and-biases, llama-cpp, serving-llms-vllm |
| email | email-inbox-triage, himalaya |
| gitlab | gitlab |
| note-taking | obsidian |
| social-media | xurl |

## 如何禁用 / 恢复（可逆）

在 `config.yaml` 的 `skills.disabled` 加/删 skill 名（**必须是 YAML 列表格式**，不是逗号字符串）：

```yaml
skills:
  disabled:
    - skill-name-a
    - skill-name-b
```

### ⚠️ 注意（踩过的坑）

- **不能用** `hermes config set skills.disabled "a,b,c"` —— 会存成单个字符串，`get_disabled_skill_names()` 会把它当成一个 skill 名（不 split）。
- **必须**是 YAML 列表。用 Python 直接改（`yaml.safe_load` → 改 `skills.disabled` 为 list → `safe_dump`），或用编辑器把 `disabled` 写成多行 `- item` 格式。
- 验证：`python -c "from agent.skill_utils import get_disabled_skill_names; print(get_disabled_skill_names())"` 应返回独立名字列表。

### 验证禁用是否生效

```python
import json
from agent.skill_utils import get_disabled_skill_names
d = json.load(open('/opt/data/.skills_prompt_snapshot.json'))
all_skills = [s.get('skill_name') for s in d.get('skills', [])]
enabled = [s for s in all_skills if s not in get_disabled_skill_names()]
print(len(all_skills), '->', len(enabled))
# 期望 90 -> 75
```

## 生效时间

- `get_disabled_skill_names()` 立即生效（直接读 config）
- 但**系统提示的 skill 列表快照**需 **重启 gateway / 新会话**（`/new`）才重新生成
- 优雅重启：`kill -USR1 <gateway-pid>`（等当前回合结束）

## 可逆性

- 用 `skills.disabled` 配置，**不删除文件**
- 恢复：把 skill 名从 `disabled` 列表移除，重启即可
- 完全可逆，无数据风险


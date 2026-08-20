---
name: search-playbook
description: 通用搜索调研：官方源优先、site限定、交叉验证、留痕存档。找职位/查店铺/市场调研皆用。
version: 1.1.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [search, research, web, verification, data-collection, market-research]
    category: research
---

# 搜索调研打法 (Search Playbook)

一套被实战验证的**通用**搜索调研方法论。适用于任何"要查真实信息"的任务:找职位、查店铺/地点、市场调研、竞品分析、验证声明、收集真实数据、价格调研、新闻报道核实。不是魔法,是可复制的流程。

## 核心原则

1. **官方源优先**:官网 > 平台本身 > 新闻 > 用户评论 > SEO 垃圾站
2. **双源交叉验证**:两个独立官方来源一致,才敢说"确认";单一来源只能标"仅供参考"
3. **递归深挖**:从一条线索顺藤摸瓜(页面 → 公司 → 详情/子页面),而不是搜一次就停
4. **留痕存档**:大页面全文存到 cache,后续从本地文件二次提取,不重复抓取
5. **诚实标注**:查不到直说查不到,分清"已确认/推测/未验证"三档

## 工具清单

- `web_search`: 主搜索。多角度并行 + `site:` 限定域名
- `web_extract`: 抓取 JS 渲染/大页面,存 cache 供二次提取
- `browser_exec`: 尝试打开被反爬的站点(失败→改用搜索索引交叉验证)
- `write_file`: 写结构化交付物(HTML 清单 / markdown 报告)
- `terminal`: 处理文件(打包 zip、正则解析缓存)
- `MEDIA:`: 把文件直接发到聊天平台(Telegram/Slack)

通用流程:搜索 → 提取 → 交叉验证(多来源确认同一事实) → 整理 → 交付。

## Firecrawl — 突破反爬的抓取工具（强烈推荐）

当 `web_extract`/`browser_exec` 被 **Cloudflare / 机器人墙 / JS 动态渲染**挡住时（如 JobStreet、LinkedIn、Google 搜索页），用 **Firecrawl**（网页抓取 API）绕过。它把任意网页转成干净 markdown。

### 配置
- `.env`: `FIRECRAWL_API_KEY=`（firecrawl.dev 注册，免费 tier）
- 直接调用其 HTTP API，无需 MCP/插件。

### 用法
```python
import urllib.request, json
key = <从 .env 读 FIRECRAWL_API_KEY>
url = "https://my.jobstreet.com/coo-jobs"   # 任意被反爬的页面
payload = {"url": url, "formats": ["markdown"], "onlyMainContent": True}
req = urllib.request.Request("https://api.firecrawl.dev/v2/scrape",
    data=json.dumps(payload).encode(),
    headers={"Content-Type":"application/json", "Authorization":f"Bearer {key}"})
with urllib.request.urlopen(req, timeout=60) as resp:
    md = (json.loads(resp.read().decode()).get('data',{}) or {}).get('markdown','')
# md 是干净 markdown —— 存缓存后正则提取数据
```

### 实战要点（已验证）
- **反爬成功率极高**：能抓 Cloudflare 保护的 JobStreet（browser 直接被挡）。实测抓到 24 个真实薪资区间（最高 RM 55-60k COO 岗）。
- **留痕存档**：抓到的大页面 `open(cache_file,'w').write(md)` 存本地，后续 grep/正则二次提取，别重复抓。
- **薪资解析**：抓列表页后 `re.finditer(r'RM\s*([0-9,]+)\s*[–-]\s*RM?\s*([0-9,]+)', md)` 提取区间。
- **注意**：付费 API，免费 tier 有限额。大任务前确认用量；只抓需要的高价值页面，别滥用。

### 何时用 Firecrawl vs web_extract
- 页面正常可抓 → `web_extract`（免费）
- 被 Cloudflare/JS 墙挡住 → **Firecrawl**（突破）


## 实操步骤

### 第 1 步:并行多路搜索(一次发 3 个不同角度的查询)

不要只搜一个 query。示例(招聘调研):
```python
web_search("site:jobstreet.com.my tech lead salary 30000")     # 限定某平台
web_search("Malaysia hiring Go tech lead RM30000 2026")        # 泛搜+年份
web_search("site:my.hiredly.com principal engineer")           # 另一平台
```
通用示例(店铺/市场):
```python
web_search("site:shopee.com.my 关键词 店铺")                    # 电商平台
web_search("market size <行业> Malaysia 2026 报告")            # 市场报告
web_search("site:官网域名 <产品> 价格")                        # 官方定价
```
- 用 `site:域名` 限定在目标平台内搜,避开 SEO 垃圾站
- 加当前年份/月份,避免旧数据
- 中英文各来一发(中文源常有独门信息,如知乎/贴吧实测;英文源覆盖国际)

### 第 2 步:先抓列表页,再抓详情页

列表页(如 jobstreet 的 `/tech-lead-jobs`、电商的分类页、报告的目录页)是整个数据集的入口:
```python
web_extract(urls=["https://目标站点/列表页"])
```
- **JS 渲染的页面 curl 抓不到**(返回几 KB 空壳)→ 用 `web_extract` 或浏览器
- web_extract 会把大页面全文存到 cache,**后续从本地文件 grep/提取,别重复抓**(cache 路径随 HERMES_HOME,如 `/opt/data/cache/web/*.md` 或 `~/.hermes/cache/web/`)
- 从列表页提取所有条目 → 用 Python 正则批量解析,别肉眼读

### 第 3 步:按条件筛选 + 递归深挖

用 Python 从缓存文件批量筛:
```python
import re
text = open(cache_file).read()
# 例:提取价格区间
for m in re.finditer(r'RM\s*([0-9,]+)\s*[–-]\s*([0-9,]+)', text, re.S):
    print(m.groups())
```
对高价值线索(高薪岗/目标店/关键数据点)再单独 `web_extract` 详情页,挖公司、要求、时间、规格。

### 第 4 步:交叉验证关键声明

- 检索词换说法再搜一遍(如 "Go Tech Lead" vs "Golang Tech Lead")看是否有多个平台同一条目
- 权威第三方(官网、官方社媒)佐证细节
- 可疑数据(如明显偏低的报价)→ 标注"数据矛盾,需核实",不要直接采信

### 第 5 步:结构化输出 + 标注可信度

- 表格输出(条目/关键数据/来源/状态),附**日期**让用户判断新鲜度
- 明确标注:✅确认 / ⚠️存疑 / ❌未找到
- 给出结论性判断(如"30k+ 在马来西亚=管理层,不是开发岗"),不要只甩数据

## 常见坑

- **curl 抓 JS 页面 = 空壳**:先 `wc -c` 看大小,<10KB 基本是渲染页,换 web_extract
- **平台限流(429)**:连续抓会 429,等一会儿或换抓取顺序
- **列表页被截断**:web_extract 有 15KB 预算,大列表用缓存文件 + `read_file` 分页读中段
- **数据陷阱**:页面常显示错误值或隐藏关键信息(薪资/价格/规格),需多源核对
- **不要一次搜完就下结论**:数据会漏,先递归挖细节再总结
- **来源优先级**:先官方后第三方,别让 SEO 垃圾站污染结论

## 验证

- 输出里的每个具体数字/条目,都能指出对应 URL 或缓存文件 → 验证通过
- 声称"确认"的信息至少两个独立来源;否则降级为"线索"
- 交付时附上数据的新鲜度(日期)和可信度标注

# Hermes Dashboard — 远程访问指南（SSH 隧道 + socat）

> 本文档记录如何从**远程电脑**安全访问 Hermes Web Dashboard（管理 Hermes 本身：sessions / channels / config / analytics）。
> 全程**不暴露公网端口**，通过 SSH 隧道加密访问。

---

## 架构

```
你的电脑 ──SSH 隧道(加密)──> ECS 宿主机(127.0.0.1:9119) ──socat──> Docker 容器(agentA:9119)
                                                                    └─> Hermes Dashboard (带密码认证)
```

- **SSH 隧道**：把宿主机 `127.0.0.1:9119` 转发到你本地，加密、只有你能连。
- **socat**：在宿主机做本地端口转发（`bind=127.0.0.1`，只本机，不暴露公网），把宿主机 9119 桥接到容器 9119。
- **认证**：Dashboard 用 `basic auth`（用户名 + 密码），登录页保护。

---

## 一、容器内启动 Dashboard（已配好认证）

Dashboard 在容器内启动，绑定 `0.0.0.0`（容器内可访问），带用户名/密码认证。

### 1. 配置认证（在 agent 的 `.env`）

编辑 `/opt/data/.env`，添加：

```bash
# Hermes Dashboard 认证（用户名/密码）
HERMES_DASHBOARD_BASIC_AUTH_USERNAME=你的用户名
HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=你的强密码
HERMES_DASHBOARD_BASIC_AUTH_SECRET=一段随机字符串（会话签名）
```

> 安全：密码用强密码。SECRET 用随机字符串（重启后保持登录态）。

### 2. 手动启动 Dashboard（容器内）

```bash
cd /opt/data
set -a; . /opt/data/.env 2>/dev/null; set +a
export HOME=/opt/data
/opt/hermes/.venv/bin/python /opt/hermes/hermes dashboard \
  --host 0.0.0.0 --port 9119 --no-open --skip-build
```

> `--skip-build` 复用已构建的 `web_dist`，避免在容器里跑 npm build。

### 3. 验证

```bash
# 应看到 302 跳登录页（说明认证生效）
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:9119/
# 应返回 basic provider
curl -s http://127.0.0.1:9119/api/auth/providers
```

**预期**：
- `curl /` → `302`（未登录跳转登录页）
- `providers` → `{"providers":[{"name":"basic",...}]}`

---

## 二、宿主机端口转发（socat）

Docker 容器**默认不暴露 9119** 到宿主机。用 socat 在宿主机做本地转发（**不重建容器、不动挂载、不丢数据**）。

### 1. 装 socat（宿主机）

```bash
sudo apt install -y socat
```

### 2. 确认容器 IP

```bash
sudo docker inspect agentA | grep IPAddress
# 通常 172.18.0.2
```

### 3. 转发（宿主机，后台运行）

```bash
# 把 <容器IP> 换成上一步查到的
sudo socat TCP-LISTEN:9119,bind=127.0.0.1,reuseaddr,fork TCP:<容器IP>:9119 &
```

**为什么安全**：`bind=127.0.0.1` 只绑定宿主机本地，**不暴露到公网**。只有能 SSH 进宿主机的人才能访问。

---

## 三、远程访问（SSH 隧道）

### 1. 在你本地电脑开 SSH 隧道

```bash
ssh -L 9119:127.0.0.1:9119 <用户>@<ECS公网IP>
```

> 保持这个终端**开着**（隧道活着）。用户通常是 `admin` 或 `root`。

### 2. 浏览器访问

打开 `http://127.0.0.1:9119`
→ 自动跳转**登录页** → 输入你在 `.env` 配的**用户名 + 密码**
→ 进入 Hermes Dashboard。

---

## 四、故障排查

| 现象 | 原因 / 解决 |
|---|---|
| 浏览器 `ERR_EMPTY_RESPONSE` | Dashboard 进程没在容器里跑。在容器内重新启动（见第一节） |
| 浏览器连不上 127.0.0.1:9119 | SSH 隧道断了。重新 `ssh -L ...` 并保持终端开着 |
| socat 连不上 | 容器 IP 不对。重新 `docker inspect agentA` 查 IP |
| 一直跳登录页进不去 | 用户名/密码不对。检查 `.env` 里的 `HERMES_DASHBOARD_BASIC_AUTH_*` |
| Dashboard 没有认证就暴露 | 危险！确认 `.env` 有认证配置，且 `--host 0.0.0.0` 未配认证会拒绝启动 |

---

## 五、安全要点

1. **SSH 隧道 + `bind=127.0.0.1`**：全程不向公网暴露 9119。
2. **必设认证**：Hermes 对非回环绑定强制要求认证（basic 或 OAuth），没认证会拒绝启动。
3. **密码强度**：用强密码；SECRET 随机。
4. **只对可信用户开放 SSH**：能 SSH 进宿主机 = 能访问 dashboard。
5. **不用 `bind=0.0.0.0` 暴露公网**：除非配了阿里云安全组限定来源 IP + 强认证。

---

## 备注

- 更省事的官方方式：容器可用 `HERMES_DASHBOARD=true` 环境变量 + `s6` 服务自动启动 dashboard（需在容器启动时注入该变量，重启容器生效）。
- 本文记录的**手动启动**方式无需重启容器，适合临时/排查场景。
- 所有真实 IP、token、密码均为占位符，配置时替换为你自己的值。

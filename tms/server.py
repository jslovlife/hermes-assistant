#!/usr/bin/env python3
"""Operator TMS — localhost console wrapping scripts/agent.sh. No docker.sock."""
from __future__ import annotations

import hashlib
import hmac
import json
import os
import re
import subprocess
import sys
from http.cookies import SimpleCookie
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parent.parent
AGENT = ROOT / "scripts" / "agent.sh"
PACKS = ROOT / "packs"
AGENTS_HOME = Path(os.environ.get("HERMES_AGENTS_HOME", Path.home() / "hermes-agents"))
HOST = os.environ.get("TMS_HOST", "127.0.0.1")
PORT = int(os.environ.get("TMS_PORT", "8787"))
PASSWORD = os.environ.get("TMS_PASSWORD", "")
STATIC = Path(__file__).resolve().parent / "static"

NAME_RE = re.compile(r"^[a-zA-Z0-9_-]+$")
SECRET_KEYS = (
    "DEEPSEEK_API_KEY",
    "OPENCODE_GO_API_KEY",
    "TELEGRAM_BOT_TOKEN",
    "TELEGRAM_ALLOWED_USERS",
    "TELEGRAM_GROUP_ALLOWED_CHATS",
    "SLACK_BOT_TOKEN",
    "SLACK_APP_TOKEN",
    "SLACK_ALLOWED_USERS",
    "GITHUB_TOKEN",
    "CUSTOM_MCP_URL",
    "CUSTOM_MCP_TOKEN",
)


def cookie_token() -> str:
    return hmac.new(b"hermes-tms", PASSWORD.encode(), hashlib.sha256).hexdigest()


def run_agent(*args: str, timeout: int = 120) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["bash", str(AGENT), *args],
        cwd=str(ROOT),
        capture_output=True,
        text=True,
        timeout=timeout,
        env={**os.environ, "HERMES_AGENTS_HOME": str(AGENTS_HOME)},
    )


def docker_running() -> set[str]:
    try:
        out = subprocess.check_output(
            ["docker", "ps", "--format", "{{.Names}}"], text=True, timeout=15
        )
    except (subprocess.SubprocessError, FileNotFoundError):
        return set()
    return {line.strip() for line in out.splitlines() if line.strip()}


def env_status(env_path: Path) -> dict[str, bool]:
    status = {k: False for k in SECRET_KEYS}
    if not env_path.is_file():
        return status
    for line in env_path.read_text(errors="replace").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        if k in status and v.strip():
            status[k] = True
    return status


def read_pack_meta(pack_id: str) -> dict:
    p = PACKS / pack_id / "pack.yaml"
    meta = {"id": pack_id, "name": pack_id, "summary": "", "coding": False}
    if not p.is_file():
        return meta
    for line in p.read_text().splitlines():
        if line.startswith("name:"):
            meta["name"] = line.split(":", 1)[1].strip()
        elif line.startswith("summary:"):
            meta["summary"] = line.split(":", 1)[1].strip()
        elif line.startswith("coding:"):
            meta["coding"] = line.split(":", 1)[1].strip().lower() == "true"
    return meta


def list_packs() -> list[dict]:
    packs = []
    if PACKS.is_dir():
        for d in sorted(PACKS.iterdir()):
            if (d / "pack.yaml").is_file():
                packs.append(read_pack_meta(d.name))
    return packs


SKIP_DIRS = {"companies", "_standalone"}


def read_agent_conf(conf: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    if not conf.is_file():
        return out
    for line in conf.read_text(errors="replace").splitlines():
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        out[k.strip()] = v.strip().strip("'")
    return out


def list_tenants() -> list[dict]:
    running = docker_running()
    tenants: list[dict] = []
    if not AGENTS_HOME.is_dir():
        return tenants
    for d in sorted(AGENTS_HOME.iterdir()):
        if not d.is_dir() or d.name in SKIP_DIRS:
            continue
        data = d / "data"
        if not data.is_dir() and not (d / "agent.conf").is_file():
            continue
        conf = read_agent_conf(d / "agent.conf")
        if conf.get("AGENT_DATA"):
            data = Path(conf["AGENT_DATA"])
        pack = ""
        pack_file = data / ".pack"
        if pack_file.is_file():
            pack = pack_file.read_text().strip()
        overlay = overlay_info(data) if data.is_dir() else {"skills": [], "has_custom_mcp": False}
        tenants.append(
            {
                "name": d.name,
                "status": "running" if d.name in running else "stopped",
                "pack": pack or None,
                "company": conf.get("COMPANY") or None,
                "role": conf.get("ROLE") or None,
                "data": str(data if data.is_dir() else ""),
                "secrets": env_status(data / ".env") if data.is_dir() else {},
                "overlay_skills": overlay["skills"],
            }
        )
    return tenants


def list_companies() -> list[dict]:
    root = AGENTS_HOME / "companies"
    companies: list[dict] = []
    if not root.is_dir():
        return companies
    tenants = list_tenants()
    for d in sorted(root.iterdir()):
        if not d.is_dir() or not (d / "company.yaml").is_file():
            continue
        roles = [
            {"name": t["name"], "role": t["role"], "status": t["status"], "pack": t["pack"]}
            for t in tenants
            if t.get("company") == d.name
        ]
        companies.append({"name": d.name, "roles": roles})
    return companies


def overlay_info(data: Path) -> dict:
    skills: list[str] = []
    custom = data / "skills-custom"
    if custom.is_dir():
        for d in sorted(custom.iterdir()):
            if d.is_dir() and (d / "SKILL.md").is_file():
                skills.append(d.name)
    custom_mcp = data / "mcp.allow.custom.yaml"
    mcp_text = custom_mcp.read_text(errors="replace") if custom_mcp.is_file() else ""
    return {
        "skills": skills,
        "has_custom_mcp": custom_mcp.is_file(),
        "mcp_yaml": mcp_text,
    }


def tenant_data_dir(name: str) -> Path:
    data = AGENTS_HOME / name / "data"
    conf = AGENTS_HOME / name / "agent.conf"
    if conf.is_file():
        parsed = read_agent_conf(conf)
        if parsed.get("AGENT_DATA"):
            data = Path(parsed["AGENT_DATA"])
    return data


def upsert_env(env_path: Path, updates: dict[str, str]) -> None:
    env_path.parent.mkdir(parents=True, exist_ok=True)
    lines = env_path.read_text().splitlines() if env_path.is_file() else []
    seen: set[str] = set()
    out: list[str] = []
    for line in lines:
        stripped = line.strip()
        if stripped and not stripped.startswith("#") and "=" in stripped:
            k = stripped.split("=", 1)[0]
            if k in updates:
                out.append(f"{k}={updates[k]}")
                seen.add(k)
                continue
        out.append(line)
    for k, v in updates.items():
        if k not in seen:
            out.append(f"{k}={v}")
    env_path.write_text("\n".join(out) + "\n")
    os.chmod(env_path, 0o600)


class Handler(BaseHTTPRequestHandler):
    server_version = "hermes-tms/1"

    def log_message(self, fmt: str, *args) -> None:
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

    def authed(self) -> bool:
        raw = self.headers.get("Cookie", "")
        jar = SimpleCookie()
        jar.load(raw)
        morsel = jar.get("tms")
        return bool(morsel) and hmac.compare_digest(morsel.value, cookie_token())

    def json(self, code: int, obj) -> None:
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def text(self, code: int, body: str, ctype: str = "text/plain; charset=utf-8") -> None:
        data = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def read_json(self) -> dict:
        n = int(self.headers.get("Content-Length") or 0)
        if n <= 0:
            return {}
        raw = self.rfile.read(n)
        return json.loads(raw.decode() or "{}")

    def do_GET(self) -> None:
        path = urlparse(self.path).path
        if path in ("/", "/index.html"):
            html = (STATIC / "index.html").read_text()
            return self.text(200, html, "text/html; charset=utf-8")
        if path == "/api/health":
            return self.json(200, {"ok": True, "bind": f"{HOST}:{PORT}"})
        if path == "/api/session":
            return self.json(200, {"ok": self.authed()})
        if not self.authed():
            return self.json(401, {"error": "login required"})
        if path == "/api/packs":
            return self.json(200, {"packs": list_packs()})
        if path == "/api/tenants":
            return self.json(200, {"tenants": list_tenants()})
        if path == "/api/companies":
            return self.json(200, {"companies": list_companies()})
        m = re.fullmatch(r"/api/tenants/([a-zA-Z0-9_-]+)/logs", path)
        if m:
            proc = run_agent("logs", m.group(1), "--once", timeout=30)
            return self.json(
                200,
                {
                    "ok": proc.returncode == 0,
                    "logs": (proc.stdout or proc.stderr)[-12000:],
                },
            )
        m = re.fullmatch(r"/api/tenants/([a-zA-Z0-9_-]+)/doctor", path)
        if m:
            proc = run_agent("doctor", m.group(1), timeout=30)
            return self.json(
                200,
                {
                    "ok": proc.returncode == 0,
                    "output": proc.stdout + proc.stderr,
                },
            )
        m = re.fullmatch(r"/api/tenants/([a-zA-Z0-9_-]+)/overlay", path)
        if m:
            data = tenant_data_dir(m.group(1))
            if not data.is_dir():
                return self.json(404, {"error": "tenant not found"})
            info = overlay_info(data)
            info["ok"] = True
            info["name"] = m.group(1)
            return self.json(200, info)
        self.json(404, {"error": "not found"})

    def do_POST(self) -> None:
        path = urlparse(self.path).path
        if path == "/api/login":
            body = self.read_json()
            if not PASSWORD or not hmac.compare_digest(str(body.get("password", "")), PASSWORD):
                return self.json(403, {"error": "bad password"})
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Set-Cookie", f"tms={cookie_token()}; HttpOnly; SameSite=Strict; Path=/")
            payload = b'{"ok":true}'
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
            return
        if not self.authed():
            return self.json(401, {"error": "login required"})
        body = self.read_json()
        if path == "/api/logout":
            self.send_response(200)
            self.send_header("Set-Cookie", "tms=; Max-Age=0; Path=/")
            self.send_header("Content-Type", "application/json")
            payload = b'{"ok":true}'
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
            return
        if path == "/api/tenants":
            name = str(body.get("name", "")).strip()
            pack = str(body.get("pack", "")).strip()
            if not NAME_RE.fullmatch(name):
                return self.json(400, {"error": "name must be alphanumeric/-/_"})
            args = ["new", name]
            if pack:
                args.append(pack)
            proc = run_agent(*args, timeout=30)
            code = 200 if proc.returncode == 0 else 400
            return self.json(code, {"ok": proc.returncode == 0, "output": proc.stdout + proc.stderr})
        if path == "/api/companies":
            name = str(body.get("name", "")).strip()
            if not NAME_RE.fullmatch(name):
                return self.json(400, {"error": "company name must be alphanumeric/-/_"})
            proc = run_agent("company", "new", name, timeout=30)
            code = 200 if proc.returncode == 0 else 400
            return self.json(code, {"ok": proc.returncode == 0, "output": proc.stdout + proc.stderr})
        m = re.fullmatch(r"/api/companies/([a-zA-Z0-9_-]+)/roles", path)
        if m:
            role = str(body.get("role", "")).strip()
            if not NAME_RE.fullmatch(role):
                return self.json(400, {"error": "role must match a pack id (cs, marketing, admin, …)"})
            proc = run_agent("company", "role", m.group(1), role, timeout=30)
            code = 200 if proc.returncode == 0 else 400
            return self.json(code, {"ok": proc.returncode == 0, "output": proc.stdout + proc.stderr})
        m = re.fullmatch(r"/api/tenants/([a-zA-Z0-9_-]+)/(up|down|restart|apply|backup)", path)
        if m:
            name, action = m.group(1), m.group(2)
            if action == "apply":
                pack = str(body.get("pack", "")).strip()
                if not pack:
                    return self.json(400, {"error": "pack required"})
                proc = run_agent("apply", name, pack, timeout=30)
            elif action == "backup":
                proc = run_agent("backup", name, timeout=120)
            elif action == "up":
                proc = run_agent("up", name, timeout=600)
            else:
                proc = run_agent(action, name, timeout=60)
            code = 200 if proc.returncode == 0 else 400
            return self.json(code, {"ok": proc.returncode == 0, "output": proc.stdout + proc.stderr})
        m = re.fullmatch(r"/api/tenants/([a-zA-Z0-9_-]+)/secrets", path)
        if m:
            name = m.group(1)
            data = tenant_data_dir(name) / ".env"
            updates = {k: str(v) for k, v in body.items() if k in SECRET_KEYS and str(v).strip()}
            if not updates:
                return self.json(400, {"error": "no allowed secret keys"})
            upsert_env(data, updates)
            return self.json(200, {"ok": True, "updated": list(updates)})
        m = re.fullmatch(r"/api/tenants/([a-zA-Z0-9_-]+)/overlay/(skill|mcp|refresh|rm-skill)", path)
        if m:
            name, action = m.group(1), m.group(2)
            if action == "refresh":
                proc = run_agent("overlay", "refresh", name, timeout=30)
            elif action == "rm-skill":
                skill = str(body.get("skill", "")).strip()
                if not NAME_RE.fullmatch(skill):
                    return self.json(400, {"error": "skill id required"})
                proc = run_agent("overlay", "rm-skill", name, skill, timeout=30)
            elif action == "skill":
                source = str(body.get("source", "")).strip()
                if not source or not Path(source).is_dir():
                    return self.json(400, {"error": "source must be a host directory with SKILL.md"})
                proc = run_agent("overlay", "add-skill", name, source, timeout=30)
            else:
                source = str(body.get("source", "")).strip()
                yaml_text = str(body.get("yaml", ""))
                if source:
                    if not Path(source).is_file():
                        return self.json(400, {"error": "yaml file not found"})
                    proc = run_agent("overlay", "mcp", name, source, timeout=30)
                elif yaml_text.strip():
                    tmp = Path("/tmp") / f"hermes-overlay-{name}.yaml"
                    tmp.write_text(yaml_text)
                    proc = run_agent("overlay", "mcp", name, str(tmp), timeout=30)
                else:
                    return self.json(400, {"error": "source or yaml required"})
            code = 200 if proc.returncode == 0 else 400
            return self.json(code, {"ok": proc.returncode == 0, "output": proc.stdout + proc.stderr})
        self.json(404, {"error": "not found"})


def main() -> None:
    if not PASSWORD:
        sys.stderr.write("TMS_PASSWORD is required. Example: TMS_PASSWORD=... ./scripts/tms.sh\n")
        sys.exit(1)
    if not AGENT.is_file():
        sys.stderr.write(f"missing {AGENT}\n")
        sys.exit(1)
    httpd = ThreadingHTTPServer((HOST, PORT), Handler)
    sys.stderr.write(f"TMS listening on http://{HOST}:{PORT} (localhost only recommended)\n")
    httpd.serve_forever()


if __name__ == "__main__":
    main()

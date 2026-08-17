#!/usr/bin/env python3
"""Merge pack + tenant-custom MCP allowlists. Stdlib only; simple YAML lists."""
from __future__ import annotations

import sys
from pathlib import Path

KEYS = ("include", "deny_until_operator_yes")


def parse_lists(text: str) -> dict[str, list[str]]:
    out = {k: [] for k in KEYS}
    current = None
    for raw in text.splitlines():
        line = raw.split("#", 1)[0].rstrip()
        if not line.strip():
            continue
        stripped = line.strip()
        if stripped.endswith(":") and not stripped.startswith("-"):
            key = stripped[:-1].strip()
            current = key if key in out else None
            continue
        if current and stripped.startswith("-"):
            val = stripped[1:].strip().strip("'\"")
            if val and val not in out[current]:
                out[current].append(val)
    return out


def load(path: Path) -> dict[str, list[str]]:
    if not path.is_file():
        return {k: [] for k in KEYS}
    return parse_lists(path.read_text(encoding="utf-8", errors="replace"))


def merge(pack: dict[str, list[str]], custom: dict[str, list[str]]) -> dict[str, list[str]]:
    merged = {}
    for key in KEYS:
        seen: list[str] = []
        for item in pack.get(key, []) + custom.get(key, []):
            if item not in seen:
                seen.append(item)
        merged[key] = seen
    return merged


def dump(merged: dict[str, list[str]]) -> str:
    lines = [
        "# Generated. Do not edit — pack apply + overlay refresh overwrite this file.",
        "# Edit mcp.allow.custom.yaml for tenant tools; pack file is mcp.allow.pack.yaml.",
        "",
    ]
    for key in KEYS:
        lines.append(f"{key}:")
        items = merged[key]
        if not items:
            lines.append("  []")
        else:
            for item in items:
                lines.append(f"  - {item}")
        lines.append("")
    return "\n".join(lines)


def main() -> int:
    if len(sys.argv) != 4:
        sys.stderr.write("usage: merge_mcp_allow.py <pack.yaml> <custom.yaml> <out.yaml>\n")
        return 2
    pack_p, custom_p, out_p = map(Path, sys.argv[1:4])
    merged = merge(load(pack_p), load(custom_p))
    out_p.write_text(dump(merged), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

---
name: qa
description: Use when testing or quality-gating work — test plans, test automation, bug reports, release acceptance.
---

# QA / Test Engineering

## When to use
- Before shipping something, writing tests, reviewing coverage, or investigating a defect.

## Build a test plan
Cover these four classes:
- **Happy path** — the main intended flow works.
- **Edge cases** — boundaries, empty input, unusual values.
- **Failure modes** — what breaks and how it fails.
- **Regressions** — existing behavior still works.

## Automate what repeats
- Turn stable, repeated checks into automated tests; keep the rest as a documented manual checklist.
- Ensure tests are deterministic (no flaky timing/ordering).

## Report a defect
Give: **steps to reproduce**, **expected** vs **actual**, **severity** (blocker/high/medium/low), and environment.

## Release gate
- Do not approve a release until acceptance criteria are met; escalate blocking defects clearly.
- State remaining risk honestly, not just "passed".

## Safety
- Do not silently change the code you are testing — report findings, let the owner fix.
- Never touch production data/systems during testing without explicit approval.

## Verify
- Tests written & run, result (pass/fail), defect report format complete, gate decision stated.

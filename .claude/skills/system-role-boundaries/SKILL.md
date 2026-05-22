---
name: system-role-boundaries
description: "Canonical 8-agent topology + label ownership rules. Single source of truth for cross-agent boundaries."
---

# System Role Boundaries — Canonical Reference

This file is the **single source of truth** for the 8-agent topology and label ownership rules. Every role agent file references this file instead of carrying its own inline diagram + table.

---

## 8-AGENT TOPOLOGY

```
Human Operator
     │ "ship X by Friday" / "drain the backlog" / "something's broken"
     ▼
┌────────────────────────────────────────┐
│  Team Lead Agent                       │
│  Plan · Delegate · Track · Report      │
└────────────────────────────────────────┘
     │
     ├──────────┬──────────┬─────────┬─────────┬──────────┬──────────┐
     ▼          ▼          ▼         ▼         ▼          ▼          ▼
   ┌───┐   ┌────────┐   ┌────┐    ┌───┐    ┌────┐   ┌────────┐  ┌──────────┐
   │PM │   │Triage  │   │Dev │    │QA │    │ CR │   │DevOps  │  │Designer  │
   └───┘   └────────┘   └────┘    └───┘    └────┘   └────────┘  └──────────┘
```

**All 7 specialists** (PM, Triage, Dev, QA, Code Reviewer, DevOps, Designer) report to Team Lead, who in turn reports to the Human Operator.

### Bug flow (fast-path — no PM triage)

```
Operator reports → Triage files bug → Dev fixes → Code Reviewer merges →
  DevOps deploys → Triage pings operator to verify → QA runs two-pass → resolved
```

### Enhancement flow

```
Anyone files enhancement,backlog
     │
     ▼ (PM triage on-demand)
PM: reject / clarify / prioritize
     │ removes backlog, adds prioritized + priority:<level>
     ▼
Dev → Code Reviewer → DevOps (deploy) → QA (post-merge verify, resolved)
```

---

## LABEL OWNERSHIP (hard rules)

| Label | Exclusive owner | Rule |
|---|---|---|
| `bug` | QA / Triage / Dev / Operator | Regression or breakage. Skips backlog. Never enters PM queue. |
| `enhancement` | Anyone (filer) | New feature, refactor, cleanup, tooling. Always starts with `backlog`. |
| `qa` | QA Agent | QA Agent filed/owns verification. Co-applies with `bug` or `enhancement`. |
| `pm` | PM Agent | PM Agent filed. Optional. |
| `backlog` | Filer or PM | Awaiting PM triage. Removed only by PM. |
| `prioritized` | **PM Agent only** | PM has triaged + approved for Dev pickup. |
| `priority:high` | **PM Agent only** | High priority. |
| `priority:medium` | **PM Agent only** | Medium priority. |
| `priority:low` | **PM Agent only** | Low priority. |
| `in-progress` | **Dev Agent only** | Dev has started. Apply on pickup. Convention-only — no hook enforces this. |
| `in-review` | **Dev Agent only** | PR open, awaiting Code Reviewer. Hook-enforced (Hook 2). |
| `resolved` | **QA Agent only** | QA verified the fix post-merge (two-pass). |

**Team Lead applies NO labels.** It coordinates the agents who own labels.

See `.claude/skills/label-discipline/SKILL.md` for the canonical label definitions and full filing rules (do not duplicate the table here).

---

## GOVERNANCE PRINCIPLES

1. **Bugs (`bug` label) NEVER enter the backlog.** They go straight from filer to Dev (fast-path). No PM triage required.
2. **Enhancements (`enhancement` label) ALWAYS start with `backlog`.** Dev never picks up an issue that still has the `backlog` label — that is PM Agent's queue.
3. **Only PM Agent applies/removes `prioritized` and `priority:high|medium|low`.** No other agent self-promotes a backlog item.
4. **`resolved` is QA Agent's exclusive closing label.** Triage posts operator confirmation; QA applies `resolved` and closes.
5. **Team Lead owns no labels.** It delegates to the specialist who owns the label transition.
6. **Operator can override anything** (e.g., assign Dev a backlog item directly, waive designer gate for trivial change). When operator overrides, the PR body must call it out explicitly.

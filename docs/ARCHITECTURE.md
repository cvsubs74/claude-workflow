# Architecture

> Update this file and append a Change Log row whenever a change touches module shape, data flow, schema, or constraints.

## System overview

This repository is the **claude-workflow** project: a Claude Code agent team that agents iterate on itself. The "system" is not a deployed web service — it is a set of shell hooks, agent role contracts, SDLC conventions, and test suites that govern how a multi-agent engineering team (Team Lead + 7 specialists) coordinates work via GitHub Issues and Pull Requests. There is no data store, no SPA, and no cloud deployment; the runtime is Claude Code running locally or in CI, driven by `.claude/settings.json`. The primary external dependency is the GitHub API (accessed via `gh` CLI).

## Module map

```
.
├── .claude/
│   ├── agents/           # Role contracts for all 8 agents (md files)
│   ├── commands/         # Slash-command prompts (/onboard-team, etc.)
│   ├── hooks/            # Enforcement scripts (Hook 1–6) + README.md
│   └── settings.json     # Hook registrations, env flags
├── docs/
│   ├── ARCHITECTURE.md   # this file
│   ├── design/           # Design docs (DESIGN-<topic>.md) for user-facing features
│   ├── playbooks/        # Per-agent scratchpads (gotchas, env quirks)
│   └── prd/              # Product requirement docs (PRD-<topic>.md)
├── tests/
│   ├── run.sh            # Entry point: bash tests/run.sh
│   ├── lib.sh            # Shared helpers (emit_payload, run_case, run_case_warn, assert_eq)
│   ├── test_hooks.sh     # Per-hook behavioral tests
│   ├── test_consistency.sh # Cross-doc drift detection
│   ├── test_repo.sh      # Repo structure sanity
│   └── fixtures/         # Stubs for hook test isolation
├── bin/                  # Operational scripts (init-project.sh, etc.)
├── CLAUDE.md             # Agent operating instructions + coding discipline
├── ETHOS.md              # Three principles: Boil the Lake, Search Before Building, User Sovereignty
└── SDLC.md               # Branch naming, PR workflow, label scheme, commit conventions
```

## Hook layout

Seven enforcement hooks run inside Claude Code's hook lifecycle. All scripts live under `.claude/hooks/` and are registered in `.claude/settings.json`. Full detail (behavior, test cases, known limitations) is in `.claude/hooks/README.md`.

| # | Script | Event type | What it enforces |
|---|--------|------------|------------------|
| 1 | `no-direct-push-main.sh` | `PreToolUse/Bash` | Blocks `git commit` on `main` and all push forms targeting a protected branch. Forces feature-branch + PR workflow (SDLC Step 2). |
| 2 | `restricted-label-ownership.sh` | `PreToolUse/Bash` | Blocks `gh issue edit`/`gh pr edit` calls that apply or remove owner-restricted labels (`prioritized`, `priority:*`, `resolved`, `in-review`, etc.) from unauthorized agents. |
| 3 | `pr-merge-requires-in-review.sh` | `PreToolUse/Bash` | Blocks `gh pr merge` when the PR does not carry the `in-review` label. Prevents Dev self-merge and premature merges before Code Reviewer sign-off. |
| 4 | `session-start-doc-check.sh` | `SessionStart` | Warns (never blocks) when required cold-start docs (`CLAUDE.md`, `ETHOS.md`, `SDLC.md`) are missing, and emits an INFO note when `docs/ARCHITECTURE.md` is absent. |
| 5 | `pr-body-closes-check.sh` | `PreToolUse/Bash` | Warns (never blocks) when `gh pr create` is called without a GitHub auto-close keyword (`Closes #N`, `Fixes #N`, `Resolves #N`) in the PR body. |
| 6 | `pr-merge-requires-delete-branch.sh` | `PreToolUse/Bash` | Blocks `gh pr merge` calls that omit `--delete-branch` (or `-d`). Enforces branch-deletion at merge time (SDLC Step 5). |
| 7 | `auto-clean-worktree.sh` | `PostToolUse/Bash` | After a successful `gh pr merge`, removes the matching `.worktrees/` entry and deletes the local branch. Closes the post-merge cleanup gap (SDLC Step 7). |

**Registration pattern in `.claude/settings.json`:**

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [{ "type": "command", "command": ".claude/hooks/<script>.sh" }] }
    ],
    "SessionStart": [
      { "hooks": [{ "type": "command", "command": ".claude/hooks/session-start-doc-check.sh" }] }
    ]
  }
}
```

`PreToolUse` hooks use a `matcher` field and can exit 2 to block. `SessionStart` hooks have no `matcher` and must always exit 0 (blocking would brick every session). See `.claude/hooks/README.md` for the full event-type comparison table.

## Agent topology

Eight roles collaborate end-to-end. The Team Lead is the lead Claude Code session; the seven specialists are sub-agents delegated to by the Team Lead or addressed directly by the operator.

```
Human Operator
     │ "ship X by Friday" / "drain the backlog" / "investigate flaky scenario Y"
     ▼
┌────────────────────────────────────────┐
│  team-lead-agent  (the lead)           │
│  Plans · Delegates · Tracks · Reports  │
└────────────────────────────────────────┘
     │
     ├──────┬──────┬──────┬──────┬─────────┬──────────┐
     ▼      ▼      ▼      ▼      ▼         ▼          ▼
  ┌────┐ ┌──────┐ ┌────┐ ┌────┐ ┌────┐ ┌────────┐ ┌──────────┐
  │ PM │ │Triage│ │Dev │ │ QA │ │ CR │ │ DevOps │ │ Designer │
  └────┘ └──────┘ └────┘ └────┘ └────┘ └────────┘ └──────────┘
```

| Agent | Primary responsibility |
|-------|----------------------|
| `team-lead-agent` | Goal decomposition, cross-agent coordination, status synthesis, escalation |
| `pm-agent` | Backlog triage, PRDs, slicing, `prioritized` + `priority:*` label ownership |
| `triage-agent` | Bug intake, 60–90s root-cause hypothesis, enriched bug filing, post-merge operator-verification |
| `dev-agent` | Code, branches, PRs, design docs; picks up `bug` and `prioritized` issues |
| `qa-agent` | Bug discovery, post-merge verification, `resolved` label, test coverage |
| `code-reviewer-agent` | PR review, merge, cross-flow contract enforcement |
| `devops-agent` | Deploys, secrets, infrastructure health checks, rollback |
| `designer-agent` | PRD UX review (mockups + open Qs), frontend PR visual quality gate |

Full role contracts live in `.claude/agents/<role>-agent.md`. The ASCII diagram and 8-role ownership table are the canonical reference in `.claude/agents/README.md`. Label ownership hard rules are the canonical reference in `.claude/skills/label-discipline/SKILL.md`.

## Test layers

All tests are plain Bash. Run everything with `bash tests/run.sh` from the repo root. See `tests/README.md` for full layout and instructions.

| File | What it catches |
|------|----------------|
| `tests/test_hooks.sh` | Per-hook behavioral correctness: allow/block decisions, edge cases (quoted args, URL forms, compound commands, refspec variants), and warn-only hooks that must always exit 0. Uses `run_case` and `run_case_warn` helpers from `tests/lib.sh`. Approximately 99 cases covering all 6 hooks. |
| `tests/test_repo.sh` | Structural sanity: `.claude/settings.json` is valid JSON, every registered hook path resolves to an executable file, all 8 expected agent files are present, all skill directories contain a `SKILL.md`, required cold-start docs (`CLAUDE.md`, `ETHOS.md`, `SDLC.md`) exist, and `bin/*.sh` pass `bash -n` syntax check. |
| `tests/test_consistency.sh` | Cross-doc drift detection: (1) label-set parity between `SDLC.md` and `label-discipline` SKILL.md; (2) hook inventory ↔ registration ↔ filesystem (hooks listed in README.md match scripts on disk and registrations in `settings.json`); (3) agent topology (8-agent list in `system-role-boundaries` SKILL.md matches agent `.md` filenames). |

## Constraints / invariants

- **No direct commits to `main`.** Every change goes through a feature branch + PR; Hook 1 enforces this mechanically.
- **PRs require `in-review` label before merge.** Hook 3 enforces this; Code Reviewer is the only role that merges.
- **Label ownership is role-locked.** Hook 2 enforces restricted labels; see `label-discipline` SKILL.md for the canonical table.
- **Branches deleted on merge.** Hook 6 enforces `--delete-branch` at command time; the GitHub repo setting is the server-side safety net.
- **Local worktrees auto-cleaned after merge.** Hook 7 fires after a successful `gh pr merge`, removes matching `.worktrees/` entries, and deletes the local branch (SDLC Step 7 invariant).
- **ARCHITECTURE.md must stay current.** Append a Change Log row on any change that touches module shape, data flow, schema, or constraints.

## External dependencies

| Service | Purpose | Failure mode if down |
|---------|---------|----------------------|
| GitHub API (`gh` CLI) | Issue tracking, PR workflow, label enforcement | Hooks 2, 3, 5, 6 cannot make API calls; agents cannot open PRs or query labels. Work can continue locally; sync when restored. |
| Claude Code runtime | Agent execution, hook lifecycle, worktree management | All agent activity pauses; no fallback. |

## Change Log

> Most recent at the top.

| Date | PR | What changed | Why |
|------|----|----|-----|
| 2026-05-22 | #TBD | Hook 7 (`auto-clean-worktree.sh`): PostToolUse hook auto-removes local worktree + branch after `gh pr merge` succeeds; all hook headers bumped "of 6" → "of 7"; `test_hooks.sh` +12 cases; `test_e2e_hook7_worktree_cleanup.sh` +10 E2E assertions | Closes recurring post-merge cleanup gap (resolves #72) |
| 2026-05-22 | #43 | Initial `docs/ARCHITECTURE.md` created from template | Eliminates session-start `[HOOK INFO]` noise; gives agents a live update surface as the system evolves (resolves #38) |
| 2026-05-22 | #42 | `SDLC.md` Step 5 + `code-reviewer-agent.md` document Designer-gate as convention-only | Honest docs about which gates are mechanical (hooks) vs convention (CR honor system) (resolves #37) |
| 2026-05-22 | #41 | Hook script headers updated "Hook N of 5" → "Hook N of 6"; Check 2b added to `tests/test_consistency.sh` | Doc rot from Hook 6 addition; new check prevents this class of drift from recurring silently (resolves #35) |
| 2026-05-22 | #40 | `label-discipline` + `system-role-boundaries` SKILLs clarify hook-enforced `in-review` vs convention-only `in-progress` | Honest about which labels are mechanically enforced vs convention-only (resolves #36) |
| 2026-05-22 | #39 | `team-lead-agent.md` inline label summary corrected: `bug` owned by QA / Triage / Dev / Operator (not Triage-only) | Drift fix; canonical owner table in `label-discipline` was right, inline summary was wrong (resolves #34) |

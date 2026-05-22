# CLAUDE.md

This file provides guidance to [Claude Code](https://docs.anthropic.com/en/docs/claude-code) when working with code in this repository.

> Fill in the `{{PLACEHOLDERS}}` for your project. `bin/init-project.sh` does this interactively.

# claude-workflow — Claude Code Agent Team

## Required cold-start reading

Before acting on any goal, load:

1. `ETHOS.md` — the three principles that override all other defaults: *Boil the Lake · Search Before Building · User Sovereignty*.
2. `SDLC.md` — branch naming, PR workflow, label scheme, commit conventions.
3. `docs/ARCHITECTURE.md` (if present) — system shape + change log.

If a doc is missing, that is a signal — propose creating it rather than working without it.

## Operating posture (must-know before any action)

- **Multi-agent team workflow.** This repo is driven by 7 specialist roles (PM, Triage, Dev, QA, Code Reviewer, DevOps, Designer) coordinated by the Team Lead — defined under `.claude/agents/`. Pick the right specialist via the `Agent` tool — don't write code directly when a Dev/QA/CR specialist is appropriate.
- **PRD → Design Doc → code.** New user-facing features require `docs/prd/PRD-<topic>.md` then `docs/design/DESIGN-<topic>.md` before implementation. Bug fixes, refactors, chores, and hotfixes skip the gate (see `SDLC.md` Step 0).
- **No direct commits to the default branch.** Every change goes through a PR; squash-merge after CI green + review.
- **Architecture doc currency.** Update `docs/ARCHITECTURE.md` + append a Change Log row whenever a change touches module shape, data flow, schema, or constraints.
- **Worktree hygiene.** Each specialist session creates its own `git worktree add` (e.g. `.worktrees/<task-id>`) off `origin/main`. Never reuse another session's worktree, and never edit inside the primary repo path — it's on whoever's branch.

## Coding discipline

Behavioral guidelines for code changes — bias toward caution over speed (use judgment on trivial tasks). Adapted from [karpathy/CLAUDE.md](https://github.com/multica-ai/andrej-karpathy-skills/blob/main/CLAUDE.md).

- **Think before coding.** State assumptions explicitly. If multiple interpretations exist, surface them — don't pick silently. If something is unclear, stop and name what's confusing rather than guessing. Push back when a simpler approach exists.
- **Simplicity first.** Minimum code that solves the problem. No features beyond what was asked, no abstractions for single-use code, no "flexibility" that wasn't requested, no error handling for impossible scenarios. If 200 lines could be 50, rewrite it. Ask: "would a senior engineer say this is overcomplicated?"
- **Surgical changes.** Touch only what the task requires. Don't "improve" adjacent code, comments, or formatting; don't refactor what isn't broken; match existing style even if you'd do it differently. Remove imports/variables your changes orphaned — leave pre-existing dead code alone (mention it, don't delete it). Every changed line should trace directly to the user's request.
- **Goal-driven execution.** Transform vague asks into verifiable success criteria before coding ("add validation" → "write tests for invalid inputs, then make them pass"; "fix the bug" → "write a test that reproduces it, then make it pass"). For multi-step work, state a brief plan with explicit verify-checks per step.
- **Boil the Lake.** AI-assisted coding makes the marginal cost of completeness near-zero. When the complete implementation costs minutes more than the shortcut — do the complete thing. See `ETHOS.md` for the full principle.

## Common commands

> Replace this block with the actual commands for your project — test, lint, dev server, deploy.

```bash
# Tests
bash tests/run.sh

# Lint / type check
# CI runs shellcheck on bin/ + markdown sanity; no local lint command

# Dev server (frontend or backend)
# (no dev server — this repo is a config/hooks template, not a deployed service)

# Deploy
# (no deploy target — see docs/ARCHITECTURE.md)
```

## Architecture in one paragraph

> Replace this with a one-paragraph description of your stack — language(s), runtime, primary data store, deploy target, major external dependencies. The kind of thing a new engineer would want before reading any code.

**Example shape:** "Two Python 3.11 Cloud Functions Gen2 in `us-east1`, a React 19 + Vite SPA on Firebase Hosting, Firestore + GCS + Cloud Tasks, and Gemini for LLM calls. Authoritative code: `cloud_functions/<service>/{main,db,validator}.py`."

## Reusable tooling

> List the scripts and Makefile targets you'd want a new agent to know about — diagnostic scripts, deploy helpers, data-fixup utilities.

- `scripts/` — diagnostic + operational scripts (promote anything you'd run more than once).
- `Makefile` — common task aliases.

## Project skills & agent playbooks

Two surfaces for capturing what an agent learns on this project — used differently.

- **Agent playbooks** (`docs/playbooks/<agent>.md`) — lightweight per-agent scratchpad. Gotchas, env quirks, "last time I tried X it broke Y." Append freely, delete when stale. Read only by that agent.
- **Project skills** (`.claude/skills/<skill-name>/SKILL.md`) — a codifiable procedure with a checklist, shared across agents or invoked often enough that drift would hurt. Claude Code auto-discovers anything under `.claude/skills/`; follow the `SKILL.md` frontmatter pattern already used by `label-discipline`, `file-bug-issue`, `worktree-management`.

**Promote-to-skill rule.** If the same multi-step procedure shows up in 2+ playbooks, or one agent has performed it 3+ times the same way, lift it out into `.claude/skills/<name>/SKILL.md`. Until then, leave it in the playbook — skills cost more to author and clutter the available-skills list when overused. The `skill-maintenance` shared skill covers the authoring pattern (frontmatter, line cap, the agent-doc-PR pattern).

## Slash commands

Run these from the Claude Code prompt:

- `/onboard-team` — spawn the 8-agent team with the Team Lead in the driver's seat.
- `/office-hours` — six forcing questions before writing code; surfaces the real problem behind the framing.
- `/plan-review` — run CEO / engineering / design review lenses on a plan or design doc.
- `/investigate` — systematic root-cause debugging. No fixes without an investigation.
- `/ship` — sync, run tests, push, open a PR (manual fallback for the Dev/CR loop).
- `/retro` — weekly retro summarizing shipping streaks, test health, growth opportunities.
- `/heartbeat` — live SDLC dry-run: ship a canary change through PM → Dev → CR, verify four exit-state criteria, report PASS / PARTIAL / FAIL.

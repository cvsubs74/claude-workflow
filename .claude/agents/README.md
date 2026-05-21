# Engineering Team

Eight-agent system that ships features end-to-end with autonomous coordination. Designed to run as a [Claude Code agent team](https://code.claude.com/docs/en/agent-teams): the **Team Lead Agent** is the lead session; **PM · Triage · Dev · QA · Code Reviewer · DevOps · Designer** are the seven specialist teammates.

## Topology

```
Human Operator
     │ "ship X by Friday" / "drain the backlog" / "investigate flaky scenario Y"
     ▼
┌────────────────────────────────────────┐
│  team-lead-agent  (the lead)           │
│  Plans · Delegates · Tracks · Reports  │
└────────────────────────────────────────┘
     │
     ├──────┬──────┬──────┬──────┬─────────┬──────────┬──────────┐
     ▼      ▼      ▼      ▼      ▼         ▼          ▼
  ┌────┐ ┌──────┐ ┌────┐ ┌────┐ ┌────┐ ┌────────┐ ┌──────────┐
  │ PM │ │Triage│ │Dev │ │ QA │ │ CR │ │ DevOps │ │ Designer │  ← 7 specialists
  └────┘ └──────┘ └────┘ └────┘ └────┘ └────────┘ └──────────┘
```

The operator sets a high-level goal. The Team Lead decomposes, delegates across the specialists, tracks progress via GitHub state, and reports only milestones and blockers. The operator stays out of day-to-day execution.

## The eight roles

| Agent | Owns | Picks up | Hands off |
|---|---|---|---|
| **`team-lead-agent`** | Goal decomposition · cross-agent coordination · status synthesis · escalation | Operator goals | Subtasks to specialists via SendMessage |
| **`pm-agent`** | Backlog triage · PRDs · slicing · `prioritized` + `priority:*` labels | `enhancement,backlog` issues | Issues to Dev queue (remove `backlog`, add `prioritized` + `priority:*`) |
| **`triage-agent`** | Bug intake · 60–90s root-cause hypothesis · enriched bug filing · post-merge operator-verification cycle | Operator bug reports | Enriched bug issue → Dev; verification confirmation → issue comment |
| **`dev-agent`** | Code · branches · PRs · design docs | `bug` (any state) · `enhancement,prioritized,priority:*` | PRs to Code Reviewer (`in-review` label) |
| **`qa-agent`** | Bug discovery · post-merge verification · `resolved` label · test coverage | Scheduled archetype runs | Bugs → Dev (`bug,qa`); enhancements → PM (`enhancement,qa,backlog`) |
| **`code-reviewer-agent`** | PR review · merge · cross-flow contract enforcement | PRs labeled `in-review` | Merge → QA's post-merge; or CHANGES REQUESTED → Dev |
| **`devops-agent`** | Deploys · secrets · infrastructure health checks · rollback | Merge events touching deployable services | Deploy confirmation comment on originating PR/issue |
| **`designer-agent`** | PRD UX review (mockups + open Qs) · frontend PR visual quality gate · accessibility | PRDs + frontend PRs in `in-review` | "Design Approved" or "Design Blocked" comment on PRD issue or PR |

Each role's full operational contract lives in `.claude/agents/<role>-agent.md`.

## Label ownership (hard rules)

- **Only PM Agent** applies/removes `prioritized` and `priority:high|medium|low`. No other agent self-promotes.
- **Only QA Agent** applies `resolved` (after independent post-merge verification).
- **Only Dev Agent** applies `in-progress` and `in-review` on issues they're actively working.
- **Team Lead applies NO labels.** It coordinates the agents who own labels.
- **Bugs (`bug`) NEVER enter the backlog** — they fast-path from Triage (or operator) to Dev.
- **Enhancements (`enhancement`) ALWAYS start with `backlog`** unless the operator pre-prioritizes.
- **Operator override**: any operator can apply any label directly; agents respect operator-set state.

Canonical reference: `.claude/skills/_shared/label-discipline/SKILL.md`.

## What stays the same (do not change per project)

- **GitHub workflow conventions**: branch naming, PR template, `Refs` vs `Closes` discipline. Defined in `SDLC.md`.
- **Worktree hygiene**: every specialist session gets its own `git worktree add .worktrees/<task-id>`.
- **Architecture doc currency**: update `docs/ARCHITECTURE.md` on any change that touches module shape, data flow, schema, constraints.

## Spawning the team (operator → lead)

**Shortcut:** type `/onboard-team` in Claude Code to inject the spawn prompt automatically.

The agent-team feature is currently experimental. This repo persists the flag at `.claude/settings.json`:

```json
{
  "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" }
}
```

Per-shell override:

```bash
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
```

Launch Claude Code from the repo root, then run `/onboard-team` or paste the spawn prompt from `.claude/commands/onboard-team.md`.

The Team Lead then:

1. Adopts the team-lead role (loads `.claude/agents/team-lead-agent.md` end-to-end).
2. Spawns all 7 specialists as sub-agents.
3. Receives operator goals, decomposes into plans, delegates via SendMessage.
4. Tracks via GitHub state; reports milestones and blockers only.
5. Escalates to operator when blocker > 4h or scope/deadline at risk.

## Anti-patterns

- The Team Lead is **not a specialist** — it doesn't write code, PRDs, tests, or reviews. If you see it doing specialist work, route the task back via delegation.
- The Team Lead **doesn't touch labels** — those are owned by the specialists.
- Specialists keep their boundaries. Team Lead doesn't ask them to do work outside their skill contract.
- Operator-direct addressing of a specialist bypasses the Team Lead — that's intentional, not a routing failure.

## You can shrink this team

Not every project needs all 8 roles. Reasonable subsets:

- **Solo dev, no UI:** Team Lead + Dev + Code Reviewer. (Skip PM, Triage, QA, DevOps, Designer.)
- **Small team, has UI:** Add Designer.
- **Pre-deploy:** Skip DevOps until you have something to deploy.
- **Bug-heavy operational repo:** Add Triage + QA early.

Delete the agent files you don't want. The remaining agents continue to work — they reference each other but degrade gracefully when a role is absent.

# claude-workflow

Opinionated boilerplate for starting a new project with [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Drop this into a fresh repo and you immediately have:

- An **8-agent team topology** — Team Lead orchestrates 7 specialists (PM, Triage, Dev, QA, Code Reviewer, DevOps, Designer) + 2 on-demand specialists (Research, Citation) so you can set goals and step away while the team executes.
- A **CLAUDE.md** that encodes operating posture, coding discipline, and the PRD → Design Doc → Contract → code workflow gate.
- An **ETHOS** — three principles that shape every decision: *Boil the Lake · Search Before Building · User Sovereignty* (adapted from [garrytan/gstack](https://github.com/garrytan/gstack)).
- **Slash commands** for the moments that matter: `/onboard-team`, `/office-hours`, `/plan-review`, `/investigate`, `/ship`, `/retro`, `/heartbeat`, `/eval`, `/swarm`, `/research`.
- **Shared skills** that codify cross-agent contracts: label discipline, role boundaries, worktree hygiene, bug-filing protocol, contract negotiation, harness mapping, think-tool wiring, tool design, safety layering, swarm dispatch, research burst, eval running, quality monitoring.
- An **eval + observability layer** — three grader types (code/LLM/state), pass@k + pass^k reporting, continuous prod quality, cross-platform equivalence, cohort segmentation. Encodes Anthropic's published eval discipline.
- A **layered safety model** — OS sandbox (`sandbox.json`) + semantic auto-mode classifier (`auto-mode.yaml`) + 12 hooks. 5 enforce PR discipline; 5 prevent the failure modes Anthropic called out in its postmortems.
- **MCP wiring** — Playwright (browser verification) + GitHub MCP by default. `.mcpb` packaging for project-local MCP servers.
- A **generic SDLC** — branch naming, PR conventions, GitHub label scheme.

The architecture is derived from the [full Anthropic engineering blog corpus](https://www.anthropic.com/engineering) — every pattern below cites the post that motivated it.

It is deliberately small and free of project-specific content. Customize once, ship many.

---

## Quick start

```bash
# 1. Clone into a new project, or copy the .claude/ + top-level docs into an existing one
git clone https://github.com/cvsubs74/claude-workflow.git my-new-project
cd my-new-project
rm -rf .git && git init -b main

# 2. Customize CLAUDE.md — fill in placeholders ({{PROJECT_NAME}}, {{GITHUB_REPO}}, etc.)
./bin/init-project.sh   # interactive — sets project name, repo, default branch

# 3. Open in Claude Code and spawn the team
claude
# then in the prompt:
/onboard-team
```

That's it. The Team Lead will read `CLAUDE.md`, anchor on recent state, and accept your first goal.

---

## What's in the box

```
.
├── CLAUDE.md                     # Operating posture, coding discipline, common commands
├── ETHOS.md                      # Boil the Lake · Search Before Building · User Sovereignty
├── SDLC.md                       # Generic PR workflow, branch naming, label scheme
├── README.md                     # You are here
├── LICENSE                       # MIT
├── .gitignore
├── .mcp.json                     # Default MCP wiring (Playwright + GitHub)
├── auto-mode.yaml                # Semantic classifier policy (environment, block_rules, allow_exceptions)
├── sandbox.json                  # OS-level isolation policy (FS allowlist, network allowlist, scoped git creds)
├── .claude/
│   ├── settings.json             # Hooks + permission allowlist
│   ├── settings.local.json.template
│   ├── agents/                   # 10 role contracts (8 always-on + 2 on-demand)
│   │   ├── team-lead-agent.md · pm-agent.md · triage-agent.md
│   │   ├── dev-agent.md · qa-agent.md · code-reviewer-agent.md
│   │   ├── devops-agent.md · designer-agent.md
│   │   ├── research-agent.md     # NEW — lead-worker for /research
│   │   └── citation-agent.md     # NEW — verification pass for research output
│   ├── skills/                   # 14 cross-agent skills
│   │   ├── label-discipline/, system-role-boundaries/, file-bug-issue/
│   │   ├── worktree-management/, skill-maintenance/
│   │   ├── harness-mapping/      # P/G/E mapping onto our 8-agent topology
│   │   ├── contract-negotiation/ # Generator ↔ Evaluator sprint contract
│   │   ├── think-tool-wiring/    # Pause-to-reason discipline
│   │   ├── tool-design/          # 7 rules from Writing tools for agents
│   │   ├── safety-layering/      # Sandbox + classifier + hooks composition
│   │   ├── swarm-dispatch/       # Partitionable bulk work via git lockfiles
│   │   ├── research-burst/       # Lead-worker discovery pattern
│   │   ├── eval-runner/          # Add and run agent/product evals
│   │   └── quality-monitor/      # Continuous prod quality + regression triage
│   ├── commands/                 # 10 slash commands
│   │   ├── onboard-team · office-hours · plan-review · investigate
│   │   ├── ship · retro · heartbeat
│   │   ├── eval · swarm · research
│   └── hooks/                    # 12 enforcement hooks
│       ├── (5 PR-discipline + 1 worktree cleanup + 1 doc check)
│       ├── workaround-audit.sh   # NEW — postmortem-prevention
│       ├── system-prompt-audit.sh# NEW — audit trail for prompt edits
│       ├── verification-gate.sh  # NEW — refuse "done" without verification
│       ├── session-opener.sh     # NEW — 3-step session opener
│       └── deploy-reminder.sh    # NEW — cohort/soak reminder on deploy prompts
├── docs/
│   ├── ARCHITECTURE.md.template
│   ├── tool-design.md            # NEW — long-form 7 tool design rules
│   ├── prd/, design/             # Where PRDs and design docs live
│   ├── contracts/                # NEW — Generator ↔ Evaluator sprint contracts
│   │   ├── README.md
│   │   └── _template.md
│   └── playbooks/                # Per-agent scratchpads
├── memory/                       # NEW — durable agent state
│   ├── PROGRESS.md · DECISIONS.md · NOTES.md
│   └── README.md
├── evals/                        # NEW — agent and product quality measurement
│   ├── tasks/, graders/, rubrics/, harness/, results/
│   ├── prod_monitor/             # Continuous quality, cross-platform eq, cohort segmentation
│   └── README.md
├── tools/                        # NEW — in-repo code-exec helpers (filesystem-as-tool-registry)
├── mcp/                          # NEW — project-local MCP servers
│   ├── servers/                  # Each shippable as .mcpb
│   ├── Makefile                  # mcpb init / mcpb pack
│   └── README.md
└── bin/
    ├── init-project.sh           # Interactive setup script (scaffolds bin/init.sh too)
    ├── gh-scoped-cred.sh         # NEW — scoped git credential helper for the sandbox
    └── (bootstrap-labels, ci-status, merge-pr, team-status)
```

---

## The 8-agent team

```
                    Human Operator
                          │
                          ▼
                ┌──────────────────┐
                │  Team Lead Agent │   ← lead session (no specialist work)
                │  plan · delegate · track · report │
                └──────────────────┘
                          │
   ┌──────┬──────┬──────┬──────┬──────────┬────────┬──────────┐
   ▼      ▼      ▼      ▼      ▼          ▼        ▼          ▼
  PM   Triage  Dev    QA   Code Rev   DevOps   Designer
```

| Agent | Owns |
|---|---|
| **Team Lead** | Goal decomposition, cross-agent coordination, status synthesis. Not a specialist. |
| **PM** | Backlog triage, PRDs, slicing, `prioritized` + `priority:*` labels. |
| **Triage** | Operator bug intake, 60–90s root-cause hypothesis, post-merge operator verification. |
| **Dev** | Code, branches, PRs, design docs. |
| **QA** | Bug discovery, post-merge verification, `resolved` label, test coverage. |
| **Code Reviewer** | PR review, merge, cross-flow contract enforcement. |
| **DevOps** | Deploys, secrets, infrastructure health checks, rollback. |
| **Designer** | PRD UX review (mockups + open Qs), frontend PR visual quality gate, accessibility. |

Each role's full contract lives in `.claude/agents/<role>-agent.md`. You can delete any agent you don't need — the team degrades gracefully.

---

## The sprint

Inspired by gstack's sprint methodology — every change flows through these stages:

> **Think → Plan → Build → Review → Test → Ship → Reflect**

- **Think** — `/office-hours` forces assumptions into the open before you write code. `/research` for breadth-first discovery.
- **Plan** — PRD (PM) + Design Doc (Dev or Designer) live in `docs/prd/` and `docs/design/`. `/plan-review` runs CEO/eng/design lenses.
- **Contract** — Generator (Dev) and Evaluators (QA + CR) negotiate a sprint contract under `docs/contracts/<N>-<slug>.md` before code. See `.claude/skills/contract-negotiation/SKILL.md`.
- **Build** — Dev picks up `prioritized` issues; works in `.worktrees/<task-id>` isolated from main. `/swarm` for partitionable bulk work.
- **Review** — Code Reviewer reviews against contract, merges. Designer gates frontend PRs.
- **Test** — QA verifies post-merge against the contract + archetype scenarios; applies `resolved`. `/eval` against the changed cohort.
- **Ship** — DevOps deploys; `/ship` opens the PR if you're doing this manually. `deploy-reminder` hook fires the cohort/soak checklist.
- **Reflect** — `/retro` summarizes shipping streaks, test health, growth opportunities. `quality-monitor` runs continuously between retros.

---

## Customizing for your project

1. **Replace placeholders.** Search the repo for `{{PROJECT_NAME}}`, `{{GITHUB_REPO}}`, `{{PRIMARY_LANGUAGE}}`, `{{DEPLOY_TARGET}}`. The `bin/init-project.sh` script does this interactively.
2. **Edit CLAUDE.md.** Add a one-paragraph "architecture in one paragraph" specific to your stack. Add your real `Common commands` block (test, dev server, deploy).
3. **Edit SDLC.md.** Adjust label scheme if your team uses different labels. Pin your branch naming convention.
4. **Trim agents you don't need.** A solo project might not need a separate Designer or DevOps agent — delete those files.
5. **Add project-specific shared skills.** As patterns emerge (deploy chain, tenant routing, etc.), add them under `.claude/skills/<name>/SKILL.md` and reference from agent files.
6. **Let agents fill their playbooks.** `docs/playbooks/<role>.md` is each agent's running notebook for project-specific knowledge — test surfaces for QA, deploy quirks for DevOps, code conventions for Dev. Agents read their own playbook on cold-start and append when they learn something worth keeping.

---

## Credits

This boilerplate combines patterns from:

- **regulatory_intelligence** — the 8-agent team topology, label discipline, system role boundaries, cold-start anchor protocol, worktree hygiene.
- **[garrytan/gstack](https://github.com/garrytan/gstack)** — the builder ethos (Boil the Lake / Search Before Building / User Sovereignty), the sprint methodology, the office-hours and investigate skill patterns.

MIT licensed. Fork it, edit it, make it yours.

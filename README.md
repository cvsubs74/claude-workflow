# claude-workflow

Opinionated boilerplate for starting a new project with [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Drop this into a fresh repo and you immediately have:

- An **8-agent team topology** — Team Lead orchestrates 7 specialists (PM, Triage, Dev, QA, Code Reviewer, DevOps, Designer) so you can set goals and step away while the team executes.
- A **CLAUDE.md** that encodes operating posture, coding discipline, and the PRD → Design Doc → code workflow gate.
- An **ETHOS** — three principles that shape every decision: *Boil the Lake · Search Before Building · User Sovereignty* (adapted from [garrytan/gstack](https://github.com/garrytan/gstack)).
- **Slash commands** for the moments that matter: `/onboard-team`, `/office-hours`, `/plan-review`, `/investigate`, `/ship`, `/retro`.
- **Shared skills** that codify cross-agent contracts: label discipline, role boundaries, worktree hygiene, bug-filing protocol.
- A **generic SDLC** — branch naming, PR conventions, GitHub label scheme.

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
├── .claude/
│   ├── settings.json             # Repo-shared Claude Code settings
│   ├── settings.local.json.template  # Per-developer template (gitignored when copied)
│   ├── agents/                   # 8 agent role contracts
│   │   ├── README.md             # Topology + spawn instructions
│   │   ├── team-lead-agent.md
│   │   ├── pm-agent.md
│   │   ├── triage-agent.md
│   │   ├── dev-agent.md
│   │   ├── qa-agent.md
│   │   ├── code-reviewer-agent.md
│   │   ├── devops-agent.md
│   │   └── designer-agent.md
│   ├── skills/                   # Cross-agent reference skills
│   │   ├── label-discipline/SKILL.md
│   │   ├── system-role-boundaries/SKILL.md
│   │   ├── file-bug-issue/SKILL.md
│   │   ├── worktree-management/SKILL.md
│   │   └── skill-maintenance/SKILL.md
│   └── commands/                 # Slash commands
│       ├── onboard-team.md
│       ├── office-hours.md
│       ├── plan-review.md
│       ├── investigate.md
│       ├── retro.md
│       └── ship.md
├── docs/
│   ├── prd/README.md             # Where PRDs live (PRD-<topic>.md)
│   ├── design/README.md          # Where design docs live (DESIGN-<topic>.md)
│   ├── playbooks/                # One per agent — running notebook for project-specific knowledge
│   │   ├── pm.md
│   │   ├── triage.md
│   │   ├── dev.md
│   │   ├── qa.md
│   │   ├── code-reviewer.md
│   │   ├── devops.md
│   │   └── designer.md
│   └── ARCHITECTURE.md.template  # Rename + fill in for your project
└── bin/
    └── init-project.sh           # One-shot interactive setup script
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

- **Think** — `/office-hours` forces assumptions into the open before you write code.
- **Plan** — PRD (PM) + Design Doc (Dev or Designer) live in `docs/prd/` and `docs/design/`. `/plan-review` runs CEO/eng/design lenses.
- **Build** — Dev picks up `prioritized` issues; works in `.worktrees/<task-id>` isolated from main.
- **Review** — Code Reviewer reviews, merges. Designer gates frontend PRs.
- **Test** — QA verifies post-merge against archetype scenarios; applies `resolved`.
- **Ship** — DevOps deploys; `/ship` opens the PR if you're doing this manually.
- **Reflect** — `/retro` summarizes shipping streaks, test health, growth opportunities.

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

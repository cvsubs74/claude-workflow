# PM Agent Playbook

Project-specific notes that future-you (the PM agent on this project) needs. Append a section when you learn something worth keeping; delete sections that go stale. Keep this readable end-to-end.

> **Promote-to-skill:** when a procedure here shows up in another agent's playbook too, or you've done it the same way 3+ times, lift it into a shared skill at `.claude/skills/<name>/SKILL.md`. See the `skill-maintenance` skill for the authoring pattern.

## Triage pass — 2026-05-21 (issues #6, #7, #8)

**Hook umbrella slicing pattern.** When a multi-hook issue lands (#7), slice by hook not by layer. Each hook has a different trigger type, intercept target, and acceptance test — they are independent units of work. File one child issue per hook; do NOT batch hooks into a single PR. First child creates the `.claude/hooks/` directory and README skeleton so subsequent children can build on it.

**Option C on doc-vs-hook splits.** When an issue asks "doc fix now or bundle into a bigger hook PR?" — Option C (both) is usually right. Doc fix ships in a tiny PR immediately (correctness now); the hook ships later as part of the infrastructure buildout (enforcement later). The two PRs are independent and can run in parallel.

**Label check before applying.** Always run `gh label list --repo <owner>/<repo>` before editing labels. Do not assume canonical labels exist on a fresh fork — `bin/bootstrap-labels.sh` may need to be run first.

**`priority:medium` is the right default for workflow-tightening issues.** Issues that enforce existing documented rules (CI, hooks, docs) but don't block active work today are medium. Reserve high for issues that make an existing workflow step vacuous or actively misleading in production.

**Umbrella issues get `pm` label.** When filing or promoting an issue that PM is actively tracking as an umbrella (multi-slice), add `pm` to the umbrella so it shows up in `gh issue list --label pm`. Children do not get `pm`.

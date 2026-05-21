# .claude/hooks — Claude Code Enforcement Hooks

Hooks are short scripts that Claude Code runs at specific lifecycle points to enforce workflow rules **mechanically**, before any PR is opened. They are the floor — not the ceiling. Agent docs explain the WHY; hooks enforce the WHAT for the mechanical subset.

See the [Claude Code hooks reference](https://docs.anthropic.com/en/docs/claude-code/hooks) for the full contract.

---

## Hook inventory

| # | File | Type | Trigger | Status |
|---|------|------|---------|--------|
| 1 | `no-direct-push-main.sh` | `PreToolUse/Bash` | `git commit` or `git push origin main` while on `main` | **Done — #9** |
| 2 | `restricted-label-ownership.sh` | `PreToolUse/Bash` | `gh issue edit --add-label` / `--remove-label` for protected labels | Coming soon — #10 |
| 3 | `pr-merge-requires-in-review.sh` | `PreToolUse/Bash` | `gh pr merge` without `in-review` label | Coming soon — #11 |
| 4 | `session-start-sanity-check.sh` | `SessionStart` | Session begin | Coming soon — #12 |
| 5 | `pr-body-closes-ref.sh` | `PreToolUse/Bash` | `gh pr create` with missing `Closes #N` | Coming soon — #13 |

---

## Hook 1: `no-direct-push-main.sh`

**Purpose:** Block direct `git commit` on `main` and `git push origin main` (or `master`). Forces all changes through a feature branch + PR, per the SDLC branch-naming rule.

**Trigger:** `PreToolUse` on tool `Bash`

**What it blocks:**
- `git commit` when the current branch is `main` or `master`
- `git push origin main`
- `git push origin master`
- `git push --force origin main` (and `--force-with-lease` variants)

**What it allows:**
- Any `git push origin <other-branch>` passes through silently
- `git commit` on any branch other than `main`/`master`

**Exit codes:**
- `0` — allow (silent)
- `2` — block (Claude Code will surface the stderr message to the user)

**Rule this enforces:** SDLC.md Step 2 — "No direct commits to the default branch. Every change goes through a PR."

---

## Hook 2: `restricted-label-ownership.sh` (coming — #10)

Blocks `gh issue edit --add-label` / `--remove-label` on protected labels (`prioritized`, `priority:*`, `resolved`, `in-review`, `pm`, `qa`) unless the calling agent is the authorized owner per `label-discipline`.

---

## Hook 3: `pr-merge-requires-in-review.sh` (coming — #11)

Blocks `gh pr merge` if the PR does not carry the `in-review` label. Prevents self-merges and premature merges before Code Reviewer has signed off.

---

## Hook 4: `session-start-sanity-check.sh` (coming — #12)

On `SessionStart`, asserts that `CLAUDE.md`, `SDLC.md`, and `ETHOS.md` exist in the repo root. Surfaces a warning (not a block) if any are missing, so the agent knows to propose creating them before acting.

---

## Hook 5: `pr-body-closes-ref.sh` (coming — #13)

Warns when `gh pr create` is called without a `Closes #N` or `Refs #N` in the PR body, reducing orphaned PRs that don't link back to their driving issue.

---

## Operator override (emergency escape hatch)

Every hook checks for the environment variable `CLAUDE_HOOK_BYPASS=1`. Set it in your shell before invoking Claude Code to disable all hook guards for that session:

```bash
CLAUDE_HOOK_BYPASS=1 claude
```

This is an **ops-emergency escape hatch only** — for security hotfixes, post-incident recovery, or cases where the hook fires incorrectly. Normal workflow violations are not emergencies. Document why you used the bypass in the commit message or PR body.

---

## How hooks are registered

Hooks are registered in `.claude/settings.json` under a `hooks` key. Example:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": ".claude/hooks/no-direct-push-main.sh" }
        ]
      }
    ]
  }
}
```

Claude Code passes a JSON object to the hook's stdin containing the tool name and input. The hook reads it, decides allow/block, and exits with 0 or 2.

---

## Adding a new hook

1. Write the script in this directory. Follow the pattern in `no-direct-push-main.sh`.
2. `chmod +x` the script.
3. Register it in `.claude/settings.json`.
4. Add a row to the inventory table above.
5. Smoke-test with a sample `stdin` payload (see each hook's header comment for examples).

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

**Purpose:** Block direct `git commit` on `main` and all push forms that target a protected remote branch (`main`, `master`, or whatever `CLAUDE_HOOK_PROTECTED_BRANCHES` lists). Forces all changes through a feature branch + PR, per the SDLC branch-naming rule.

**Trigger:** `PreToolUse` on tool `Bash`

**What it blocks — all forms including refspec bypasses:**
- `git push origin main` (simple)
- `git push origin master`
- `git push --force origin main` / `git push -f origin main`
- `git push -u origin main`
- `git push origin HEAD:main` (refspec — pushes current HEAD to remote main)
- `git push origin refs/heads/main` (full refname)
- `git push origin main:main` (explicit local:remote refspec)
- `git push origin +main` (force-push shorthand via leading `+`)
- `git push origin :main` (delete remote branch)
- `git push origin +main:main` / `git push origin +refs/heads/main` (combined force + refspec)
- `git push 'origin' 'main'` / `git push "origin" "main"` (shell-quoted args — both forms)
- `git push 'origin' 'HEAD:main'` / `git push "origin" "HEAD:refs/heads/main"` (quoted + refspec combined)
- `git commit` when the current branch is `main` or `master`

**What it allows:**
- Any `git push origin <other-branch>` — e.g. `feat/9-my-branch`
- `git push origin mainline` — no false positive on branch names that contain `main`
- `git push upstream main` — different remote, out of scope per issue #9 non-goals
- `git commit` on any branch other than `main`/`master`

**Exit codes:**
- `0` — allow (silent)
- `2` — block (Claude Code will surface the stderr message to the user)

**Rule this enforces:** SDLC.md Step 2 — "No direct commits to the default branch. Every change goes through a PR."

---

### Configuring protected branches

The hook reads the `CLAUDE_HOOK_PROTECTED_BRANCHES` environment variable (space-separated list of branch names). If the variable is not set, it defaults to `main master`.

```bash
# Example: also protect 'develop' and 'release'
export CLAUDE_HOOK_PROTECTED_BRANCHES="main master develop release"
```

Add the export to your shell profile or to the `env` block in `.claude/settings.json` for project-wide enforcement.

---

### Running the self-test

The hook ships with a `--self-test` flag that exercises all known block and allow cases and reports PASS/FAIL per case:

```bash
# Run from any feature branch (not from main — the commit-guard test
# reflects real git context, so running from main will block commit cases)
bash .claude/hooks/no-direct-push-main.sh --self-test
```

Expected output (all 25 cases green):

```
=== no-direct-push-main.sh --self-test ===

--- SHOULD BLOCK (exit 2) ---
  PASS  git push origin main                                     (block)
  PASS  git push origin master                                   (block)
  PASS  git push --force origin main                             (block)
  PASS  git push -f origin main                                  (block)
  PASS  git push -u origin main                                  (block)
  PASS  git push origin HEAD:main                                (block)
  PASS  git push origin refs/heads/main                          (block)
  PASS  git push origin main:main                                (block)
  PASS  git push origin +main                                    (block)
  PASS  git push origin :main  (delete remote)                   (block)
  PASS  git push origin +main:main                               (block)
  PASS  git push origin +refs/heads/main                         (block)
  PASS  git push origin HEAD:refs/heads/main                     (block)
  PASS  git push 'origin' 'main'  (single-quoted args)           (block)
  PASS  git push "origin" "main"  (double-quoted args)           (block)
  PASS  git push 'origin' 'HEAD:main'  (quoted + refspec)        (block)
  PASS  git push "origin" "HEAD:refs/heads/main"  (quoted)       (block)

--- SHOULD ALLOW (exit 0) ---
  PASS  git push origin feat/9-branch                            (allow)
  PASS  git push origin mainline  (no false positive)            (allow)
  PASS  git push origin feat/main-fix  (contains main)           (allow)
  PASS  git push upstream main  (different remote)               (allow)
  PASS  git push 'origin' 'feat/x'  (quoted, allowed branch)     (allow)
  PASS  git commit -m fix  (on feature branch)                   (allow)
  PASS  ls -la  (non-git command)                                (allow)
  PASS  bypass via CLAUDE_HOOK_BYPASS=1                          (allow)

=== Results: 25 passed, 0 failed ===
```

Run the self-test whenever you modify the hook script to catch regressions before pushing.

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
5. Add a `--self-test` block to the script.
6. Smoke-test with a sample `stdin` payload (see each hook's header comment for examples).

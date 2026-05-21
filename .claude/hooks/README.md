# .claude/hooks — Claude Code Enforcement Hooks

Hooks are short scripts that Claude Code runs at specific lifecycle points to enforce workflow rules **mechanically**, before any PR is opened. They are the floor — not the ceiling. Agent docs explain the WHY; hooks enforce the WHAT for the mechanical subset.

See the [Claude Code hooks reference](https://docs.anthropic.com/en/docs/claude-code/hooks) for the full contract.

---

## Hook inventory

| # | File | Type | Trigger | Status |
|---|------|------|---------|--------|
| 1 | `no-direct-push-main.sh` | `PreToolUse/Bash` | `git commit` or `git push origin main` while on `main` | **Done — #9** |
| 2 | `restricted-label-ownership.sh` | `PreToolUse/Bash` | `gh issue edit --add-label` / `--remove-label` for protected labels | **Done — #10** |
| 3 | `pr-merge-requires-in-review.sh` | `PreToolUse/Bash` | `gh pr merge` without `in-review` label | **Done — #11** |
| 4 | `session-start-doc-check.sh` | `SessionStart` | Session begin | **Done — #12** |
| 5 | `pr-body-closes-check.sh` | `PreToolUse/Bash` | `gh pr create` with missing `Closes #N` | **Done — #13** |

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

## Hook 2: `restricted-label-ownership.sh`

**Purpose:** Block `gh issue edit` and `gh pr edit` calls that apply or remove owner-restricted labels unless the calling agent is the declared owner per `label-discipline`.

**Trigger:** `PreToolUse` on tool `Bash`

**Restricted label → authorised agents:**

| Label | Authorised agents |
|-------|------------------|
| `prioritized` | `pm-agent` |
| `priority:high` | `pm-agent` |
| `priority:medium` | `pm-agent` |
| `priority:low` | `pm-agent` |
| `pm` | `pm-agent` |
| `resolved` | `qa-agent` |
| `qa` | `qa-agent` |
| `in-review` | `dev-agent`, `code-reviewer-agent` |

All other labels (`bug`, `enhancement`, `backlog`, `in-progress`, etc.) are unrestricted — any agent may apply them.

**What it blocks:**
- `gh issue edit <n> --add-label prioritized` from any non-PM agent
- `gh pr edit <n> --remove-label in-review` from any agent other than dev or code-reviewer
- Any combination of the above

**What it allows:**
- Owner applying their own label
- Non-restricted labels (no check performed)
- Operator direct sessions where `agent_type` is absent in hook stdin (fail-open with WARNING — see §Limitation below)
- `CLAUDE_HOOK_BYPASS=1` emergency override

**Exit codes:**
- `0` — allow (silent, or WARNING to stderr when agent identity is absent)
- `2` — block (Claude Code surfaces stderr to the user)

**Rule this enforces:** `label-discipline` SKILL.md hard rules 2, 3, and 4.

---

### Running the self-test

```bash
bash .claude/hooks/restricted-label-ownership.sh --self-test
```

Expected output (all 30 cases green):

```
=== restricted-label-ownership.sh --self-test ===

--- SHOULD BLOCK (exit 2) ---
  PASS  dev adds priority:high                                        (block)
  PASS  dev adds prioritized                                          (block)
  PASS  qa adds priority:medium                                       (block)
  PASS  triage adds priority:low                                      (block)
  PASS  dev adds pm label                                             (block)
  PASS  dev removes prioritized                                       (block)
  PASS  dev adds resolved                                             (block)
  PASS  pm adds resolved                                              (block)
  PASS  dev adds qa label                                             (block)
  PASS  pm adds qa label                                              (block)
  PASS  pm adds in-review                                             (block)
  PASS  qa adds in-review                                             (block)
  PASS  triage removes in-review                                      (block)

--- SHOULD ALLOW (exit 0) ---
  PASS  pm adds priority:high (owner)                                 (allow)
  PASS  pm adds prioritized (owner)                                   (allow)
  PASS  pm adds priority:medium (owner)                               (allow)
  PASS  pm adds priority:low (owner)                                  (allow)
  PASS  pm adds pm label (owner)                                      (allow)
  PASS  qa adds resolved (owner)                                      (allow)
  PASS  qa adds qa label (owner)                                      (allow)
  PASS  dev adds in-review (owner)                                    (allow)
  PASS  code-reviewer adds in-review (owner)                          (allow)
  PASS  code-reviewer removes in-review (owner)                       (allow)
  PASS  dev adds plain enhancement label                              (allow)
  PASS  dev adds bug label                                            (allow)
  PASS  qa adds backlog label                                         (allow)
  PASS  no agent context adds prioritized (fail-open)                 (allow)
  PASS  bypass via CLAUDE_HOOK_BYPASS=1                               (allow)
  PASS  git push (non-gh command, allow)                              (allow)
  PASS  ls -la (non-gh command, allow)                                (allow)

=== Results: 30 passed, 0 failed ===
```

---

### Limitation: agent identity

Claude Code sets `agent_type` in the hook stdin JSON **only when running inside a subagent context** (spawned via `--agent` flag or the `Agent` tool). When an operator runs Claude Code directly (no agent wrapper), `agent_type` is absent and the hook **fails open** — it emits a stderr WARNING but allows the label operation through.

This is intentional: operators are trusted principals and can apply any label per the Operator Override Clause in `label-discipline`. The WARNING is a signal to the operator that enforcement was skipped.

**Follow-up:** If full enforcement for all interactive sessions is needed, a separate mechanism (e.g. reading the active agent name from a session env var or settings override) would be required. File an enhancement issue with label `enhancement,backlog` if this gap needs to be closed.

---

## Hook 3: `pr-merge-requires-in-review.sh`

**Purpose:** Block `gh pr merge` if the PR does not carry the `in-review` label. Prevents Dev agents from self-merging and premature merges before the Code Reviewer has signed off.

**Trigger:** `PreToolUse` on tool `Bash`

**What it blocks — all forms including flags and compound commands:**
- `gh pr merge 5` (simple)
- `gh pr merge --squash 5` (flag before number)
- `gh pr merge 5 --squash` (flag after number)
- `gh pr merge 5 --squash --delete-branch` (multiple flags)
- `gh pr merge '5'` / `gh pr merge "5"` (quoted number — both forms)
- `gh pr merge https://github.com/owner/repo/pull/5` (URL form)
- `cd /tmp && gh pr merge 5` (compound command)

**What it allows:**
- `gh pr merge <N>` when PR `<N>` carries the `in-review` label — passes through silently
- `gh pr view`, `gh pr create`, `gh issue close`, and all other non-merge `gh` subcommands
- Any non-`gh` command (`git`, `ls`, etc.)

**Exit codes:**
- `0` — allow (silent)
- `2` — block (Claude Code surfaces the stderr message to the user)

**Rule this enforces:** SDLC.md Step 5 — "Code Reviewer merges. Always."

---

### Running the self-test

The hook ships with a `--self-test` flag that exercises 18 cases across all documented forms:

```bash
bash .claude/hooks/pr-merge-requires-in-review.sh --self-test
```

The self-test is fully hermetic — it uses `CLAUDE_HOOK_GH_LABELS_CMD` to stub the `gh pr view` call and never makes real GitHub API requests. PR #42 and #7 are the "has in-review" mocks; all other numbers return labels without `in-review`.

Expected output (all 18 cases green):

```
=== pr-merge-requires-in-review.sh --self-test ===

--- SHOULD BLOCK (exit 2) ---
  PASS  gh pr merge 5  (no in-review)                                 (block)
  PASS  gh pr merge --squash 5  (flag before num)                     (block)
  PASS  gh pr merge 5 --squash  (flag after num)                      (block)
  PASS  gh pr merge 5 --squash --delete-branch                        (block)
  PASS  gh pr merge '5'  (single-quoted number)                       (block)
  PASS  gh pr merge "5"  (double-quoted number)                       (block)
  PASS  compound: cd /tmp && gh pr merge 5                            (block)
  PASS  URL form: gh pr merge .../pull/5                              (block)

--- SHOULD ALLOW (exit 0) ---
  PASS  gh pr merge 42  (has in-review)                               (allow)
  PASS  gh pr merge --squash 42  (in-review, flag)                    (allow)
  PASS  gh pr merge 7 --squash  (in-review, flag)                     (allow)
  PASS  gh pr view 5  (not a merge command)                           (allow)
  PASS  gh pr create  (not a merge command)                           (allow)
  PASS  gh issue close 5  (non-pr command)                            (allow)
  PASS  gh issue edit 5 --add-label in-review                         (allow)
  PASS  ls -la  (non-gh command)                                      (allow)
  PASS  git push origin feat/11-branch                                (allow)
  PASS  CLAUDE_HOOK_BYPASS=1 with blocked PR                          (allow)

=== Results: 18 passed, 0 failed ===
```

---

## Hook 4: `session-start-doc-check.sh` — Done (#12)

**Purpose:** Sanity-check that required cold-start docs exist in the repo root at session start. Surfaces a warning (not a block) if any required doc is missing, so the agent knows to propose creating it before acting.

**Trigger:** `SessionStart` event — fires once per Claude Code session, before the agent takes any action.

**Event type: SessionStart**

`SessionStart` is a different hook event type from `PreToolUse`. It fires once when Claude Code starts a new session, not on each tool call. Its JSON stdin payload contains session metadata (e.g. `session_id`, `transcript_path`) rather than tool input. It is registered under the top-level `SessionStart` key in `.claude/settings.json` (NOT inside `PreToolUse`), and does not use a `matcher` field.

```json
"hooks": {
  "SessionStart": [
    {
      "hooks": [
        { "type": "command", "command": ".claude/hooks/session-start-doc-check.sh" }
      ]
    }
  ]
}
```

**Required docs checked:**
- `CLAUDE.md` — agent operating instructions (required)
- `ETHOS.md` — the three principles that override all defaults (required)
- `SDLC.md` — branch naming, PR workflow, label scheme (required)
- `docs/ARCHITECTURE.md` — system shape + change log (optional; informational note if absent)

**This hook NEVER BLOCKS.** Exit code is always 0. Blocking `SessionStart` would brick every session. The hook is a warning surface only.

**Exit codes:**
- `0` — always

**Test-root override (for self-test and CI):**
- `--test-root <dir>` flag, or `CLAUDE_HOOK_TEST_ROOT=<dir>` env var — use `<dir>` as the repo root instead of `$PWD`. Flag takes precedence over env var.

### Running the self-test

```bash
bash .claude/hooks/session-start-doc-check.sh --self-test
```

Expected output (all 7 cases green):

```
=== session-start-doc-check.sh --self-test ===

--- REQUIRED FILES PRESENT / ABSENT ---
  PASS  all required files present — no warnings
  PASS  ETHOS.md missing — warning for ETHOS.md
  PASS  SDLC.md missing — warning for SDLC.md
  PASS  CLAUDE.md missing — warning for CLAUDE.md
  PASS  all three required missing — three warnings
  PASS  docs/ARCHITECTURE.md missing alone — info note not warning

--- BYPASS ---
  PASS  CLAUDE_HOOK_BYPASS=1 — silent regardless of missing files

=== Results: 7 passed, 0 failed ===
```

---

## Hook 5: `pr-body-closes-check.sh` — Done (#13)

**Purpose:** Warn (never block) when `gh pr create` is called without a GitHub auto-close keyword in the PR body. Reduces orphaned PRs that silently fail to close their tracking issues on merge.

**Rationale:** dev-agent.md §5 establishes that `Closes #N` is mandatory for any PR that fully resolves a tracking issue. This hook makes accidental omission visible rather than silent.

**Trigger:** `PreToolUse` on tool `Bash`

**What it warns on:**
- `gh pr create --body "some text"` where the body lacks any auto-close keyword
- `gh pr create --body-file path/to/file` where the file content lacks any auto-close keyword

**What it allows silently:**
- `gh pr create --body "Closes #5"` (or any GitHub auto-close keyword — see below)
- `gh pr create` (no `--body` or `--body-file` — interactive edit, can't check)
- `gh pr create --body-file <path>` where the file does not exist or is not readable
- Any non-`gh pr create` command

**Accepted auto-close keywords (case-insensitive):**
- `Closes #N` / `Close #N`
- `Fixes #N` / `Fix #N`
- `Resolves #N` / `Resolve #N`

`Refs #N` is intentionally NOT in the accepted list — it does not auto-close the issue, so the warning is appropriate.

**Exit codes:**
- `0` — always (warn-only hook; never blocks)

**Running the self-test:**

```bash
bash .claude/hooks/pr-body-closes-check.sh --self-test
```

Expected output (all 19 cases green):

```
=== pr-body-closes-check.sh --self-test ===

--- SHOULD ALLOW (no warning, exit 0) ---
  PASS  gh pr create --body "Closes #5"                                 (allow)
  PASS  gh pr create --body "Fixes #5"                                  (allow)
  PASS  gh pr create --body "Resolves #5"                               (allow)
  PASS  gh pr create --body "Close #5"                                  (allow)
  PASS  gh pr create --body "Fix #5"                                    (allow)
  PASS  gh pr create --body "Resolve #5"                                (allow)
  PASS  gh pr create --body "closes #5" (lowercase)                     (allow)
  PASS  gh pr create --body "CLOSES #5" (uppercase)                     (allow)
  PASS  gh pr create --body multiline (literal \n) with Closes #5       (allow)
  PASS  gh pr create (interactive, no body flag)                        (allow)
  PASS  gh pr create --draft (no body flag)                             (allow)
  PASS  gh pr create --body-file with Closes #N                         (allow)
  PASS  gh pr create --body-file nonexistent (allow through)            (allow)
  PASS  cd /tmp && gh pr create --body "Closes #5" (compound cmd)       (allow)
  PASS  bypass via CLAUDE_HOOK_BYPASS=1                                 (allow)
  PASS  git status (non-gh command)                                     (allow)

--- SHOULD WARN (missing auto-close keyword, exit 0) ---
  PASS  gh pr create --body "lorem ipsum"                               (warn)
  PASS  gh pr create --body "refs #5" (refs is not auto-close)          (warn)
  PASS  gh pr create --body-file without Closes #N                      (warn)

=== Results: 19 passed, 0 failed ===
```

---

## Operator override (emergency escape hatch)

Every hook checks for the environment variable `CLAUDE_HOOK_BYPASS=1`. Set it in your shell before invoking Claude Code to disable all hook guards for that session:

```bash
CLAUDE_HOOK_BYPASS=1 claude
```

This is an **ops-emergency escape hatch only** — for security hotfixes, post-incident recovery, or cases where the hook fires incorrectly. Normal workflow violations are not emergencies. Document why you used the bypass in the commit message or PR body.

---

## How hooks are registered

Hooks are registered in `.claude/settings.json` under a `hooks` key. Different event types use different top-level keys. Example showing both `PreToolUse` and `SessionStart`:

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
    ],
    "SessionStart": [
      {
        "hooks": [
          { "type": "command", "command": ".claude/hooks/session-start-doc-check.sh" }
        ]
      }
    ]
  }
}
```

**Key differences by event type:**

| Event | `matcher` field | stdin payload | Exit 2 = block? |
|-------|----------------|---------------|-----------------|
| `PreToolUse` | Required — matches the tool name (e.g. `"Bash"`) | `{"tool_name":"...","tool_input":{...}}` | Yes — blocks the tool call |
| `SessionStart` | Not used | `{"session_id":"...","transcript_path":"..."}` | No — must always exit 0 |

Claude Code passes a JSON object to the hook's stdin. For `PreToolUse`, the hook reads the command, decides allow/block, and exits with 0 or 2. For `SessionStart`, the hook must always exit 0 — blocking would brick the session.

---

## Adding a new hook

1. Write the script in this directory. Follow the pattern in `no-direct-push-main.sh`.
2. `chmod +x` the script.
3. Register it in `.claude/settings.json`.
4. Add a row to the inventory table above.
5. Add a `--self-test` block to the script.
6. Smoke-test with a sample `stdin` payload (see each hook's header comment for examples).

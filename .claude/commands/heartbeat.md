---
description: Live SDLC dry-run — ship a canary change through the full PM → Dev → CR pipeline and verify four exit-state criteria.
---

# /heartbeat

You are the Team Lead. Run the full PM → Dev → CR pipeline against a trivial canary change, then verify the four exit-state criteria and report PASS / PARTIAL / FAIL. Do not ask for permission at each step — execute end-to-end autonomously and report the result.

---

## Canary design

The canary file is `docs/HEARTBEAT.md`. It contains a line:

```
Run count: N
```

Each `/heartbeat` invocation increments N by 1. The change is always a 1-digit (or multi-digit) integer bump — safe to land on `main`, zero behavioral side-effects, fully idempotent across runs.

**Before starting:** read the current count from `docs/HEARTBEAT.md`:

```bash
grep "^Run count:" docs/HEARTBEAT.md
```

Let N = current count. The run you are about to execute is run N+1.

---

## Step 1 — PM phase: file the canary issue

File an issue with exactly these attributes:

- **Title:** `[CHORE] /heartbeat run <N+1> — increment canary`
- **Body:** `Heartbeat run — canary change. Increment \`docs/HEARTBEAT.md\` Run count from <N> to <N+1>.`
- **Labels:** `enhancement,prioritized,priority:low`

```bash
gh issue create \
  --title "[CHORE] /heartbeat run <N+1> — increment canary" \
  --body "Heartbeat run — canary change. Increment \`docs/HEARTBEAT.md\` Run count from <N> to <N+1>." \
  --label "enhancement,prioritized,priority:low"
```

Capture the issue number as ISSUE_NUM. Apply `in-progress` immediately:

```bash
gh issue edit <ISSUE_NUM> --add-label "in-progress"
```

Note: `/heartbeat` is the one place where PM and Team Lead are the same actor, so PM-only labels (`prioritized`, `priority:low`) are applied directly here by design.

---

## Step 2 — Dev phase: worktree + canary change + PR

### 2a. Create the worktree

```bash
git fetch origin
git worktree add .worktrees/heartbeat-<N+1> -b chore/<ISSUE_NUM>-heartbeat-<N+1> origin/main
```

### 2b. Increment the counter

Edit `docs/HEARTBEAT.md` in the worktree — change `Run count: <N>` to `Run count: <N+1>`.

### 2c. Commit

```bash
git -C .worktrees/heartbeat-<N+1> add docs/HEARTBEAT.md
git -C .worktrees/heartbeat-<N+1> commit -m "chore(heartbeat): increment canary to <N+1>"
git -C .worktrees/heartbeat-<N+1> push -u origin chore/<ISSUE_NUM>-heartbeat-<N+1>
```

### 2d. Open PR + apply in-review

```bash
gh pr create \
  --title "chore(heartbeat): increment canary to <N+1>" \
  --body "$(cat <<'EOF'
## Summary
- Increment heartbeat canary counter from <N> to <N+1>
- Live SDLC pipeline probe

## Test plan
- [ ] Counter line in docs/HEARTBEAT.md reads `Run count: <N+1>`
- [ ] Issue #<ISSUE_NUM> auto-closes on merge (Closes in body)
- [ ] Branch deleted on merge (--delete-branch)

Closes #<ISSUE_NUM>
EOF
)" \
  --head chore/<ISSUE_NUM>-heartbeat-<N+1>
```

Capture the PR number as PR_NUM. Apply `in-review`:

```bash
gh pr edit <PR_NUM> --add-label "in-review"
```

**Known lesson (from real run #79→#80):** `Closes #N` in the PR body is what auto-closes the issue on merge. `Refs #N` leaves the issue open. Always use `Closes` here — the heartbeat issue has no follow-on work.

---

## Step 3 — CR phase: review and merge

Code Reviewer (you, acting in CR role) inspects the diff — it is a 1-line counter increment, nothing else. There is no logic change. Merge:

```bash
gh pr merge <PR_NUM> --squash --delete-branch
```

`--delete-branch` is required by Hook 6 (`pr-merge-requires-delete-branch.sh`). If the hook rejects the merge because `--delete-branch` is missing, that is a FAIL — report the exact hook error.

**Note on Hook 7:** Hook 7 (`auto-clean-worktree.sh`) should fire on merge to remove the local worktree automatically. As of 2026-05-22 Hook 7 is silent in agent context (issue #81 tracks the fix). Don't rely on it — clean up manually in Step 4 regardless.

---

## Step 4 — Verify the four exit-state criteria

Run each check and record PASS/FAIL per criterion.

### Criterion 1 — Issue closed

```bash
gh issue view <ISSUE_NUM> --json state --jq '.state'
# Expected: "CLOSED"
```

### Criterion 2 — No open PRs for this canary branch

```bash
gh pr list --state open --search "head:chore/<ISSUE_NUM>-heartbeat-<N+1>" --json number
# Expected: empty array []
```

### Criterion 3 — Worktree removed

```bash
git worktree list | grep "heartbeat-<N+1>"
# Expected: no output (worktree gone)
```

If the worktree is still present (Hook 7 silent in agent context), remove it manually:

```bash
git worktree remove .worktrees/heartbeat-<N+1>
```

Then re-run the check — it must pass before reporting.

### Criterion 4 — Local and remote branch gone

```bash
git branch --list chore/<ISSUE_NUM>-heartbeat-<N+1>
# Expected: no output

git ls-remote --heads origin chore/<ISSUE_NUM>-heartbeat-<N+1>
# Expected: no output
```

If the local branch survived, delete it:

```bash
git branch -D chore/<ISSUE_NUM>-heartbeat-<N+1>
```

Then re-run the check.

---

## Step 5 — Report

Print a structured report. Use exactly this format:

```
/heartbeat run <N+1> — PASS
  Criterion 1 (issue closed):        PASS  — #<ISSUE_NUM> state=CLOSED
  Criterion 2 (PR cleaned up):       PASS  — 0 open PRs for chore/<ISSUE_NUM>-heartbeat-<N+1>
  Criterion 3 (worktree removed):    PASS  — .worktrees/heartbeat-<N+1> not in worktree list
  Criterion 4 (branch deleted):      PASS  — local gone, remote gone
```

If any criterion fails after manual remediation attempts:

```
/heartbeat run <N+1> — PARTIAL
  Criterion 1 (issue closed):        PASS  — #<ISSUE_NUM> state=CLOSED
  Criterion 2 (PR cleaned up):       PASS  — 0 open PRs
  Criterion 3 (worktree removed):    FAIL  — .worktrees/heartbeat-<N+1> still present; Hook 7 silent (#81 open)
  Criterion 4 (branch deleted):      PASS  — local gone, remote gone

  Action: worktree left as artifact; file a follow-up or re-run after #81 is resolved.
```

If the pipeline could not complete at all:

```
/heartbeat run <N+1> — FAIL
  Blocked at: <CR phase / Dev phase / PM phase>
  Error: <exact error message or hook output>
  Remediation: <what the operator should do next>
```

---

## Defect lessons baked in (so fresh sessions don't repeat them)

1. **`Closes #N` not `Refs #N`.** The heartbeat issue has no follow-on work; `Refs` leaves it dangling open. (Confirmed via PR #80 auto-closing issue #79.)
2. **`in-review` on the PR, not just the issue.** Code Reviewer watches for `in-review` on the PR object. (`gh pr edit <N> --add-label in-review`)
3. **`--delete-branch` is mandatory on merge.** Hook 6 rejects merges without it. The flag also cleans the remote tracking ref.
4. **Don't trust Hook 7 until #81 is resolved.** Clean the worktree and local branch manually in the verification step regardless of whether the hook fires.

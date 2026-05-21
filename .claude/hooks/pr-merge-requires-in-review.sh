#!/usr/bin/env bash
# pr-merge-requires-in-review.sh — Hook 3 of 5
#
# PreToolUse / Bash hook: block `gh pr merge` when the PR does not carry
# the `in-review` label.
#
# Claude Code invokes this script for every Bash tool call. It receives a JSON
# object on stdin with the following shape (as of Claude Code hooks contract):
#
#   {
#     "tool_name": "Bash",
#     "tool_input": {
#       "command": "<the bash command string>"
#     }
#   }
#
# Exit codes:
#   0  — allow (silent)
#   2  — block (Claude Code surfaces stderr to the user)
#
# Smoke-test examples:
#   Block:   echo '{"tool_name":"Bash","tool_input":{"command":"gh pr merge 5"}}' | bash pr-merge-requires-in-review.sh
#   Block:   echo '{"tool_name":"Bash","tool_input":{"command":"gh pr merge --squash 5"}}' | bash pr-merge-requires-in-review.sh
#   Allow:   echo '{"tool_name":"Bash","tool_input":{"command":"gh pr view 5"}}' | bash pr-merge-requires-in-review.sh
#
# Self-test: run with --self-test to verify all cases pass:
#   bash pr-merge-requires-in-review.sh --self-test
#
# Operator override: set CLAUDE_HOOK_BYPASS=1 to skip all checks.
#
# gh pr view mock: in --self-test the CLAUDE_HOOK_GH_LABELS_CMD env var can
# override the label-fetching command. Self-test sets it to a function stub
# that returns a controlled JSON array — no real GitHub API calls needed.
#
# See .claude/hooks/README.md for full escape-hatch documentation and
# .claude/skills/label-discipline/ for label ownership rules.

set -euo pipefail

# ---------------------------------------------------------------------------
# Self-test mode
# ---------------------------------------------------------------------------
if [[ "${1:-}" == "--self-test" ]]; then
  SCRIPT="$0"
  PASS=0
  FAIL=0

  # -------------------------------------------------------------------------
  # Mock strategy: The --self-test runs without real GitHub API access.
  # We use a wrapper script trick via CLAUDE_HOOK_GH_LABELS_CMD:
  #   - When CLAUDE_HOOK_GH_LABELS_CMD is set, the hook uses it instead of
  #     calling `gh pr view <N> --json labels ...`.
  #   - In self-test, we set this env var to a small bash snippet that
  #     returns a fixed label JSON array based on the PR number:
  #       PR 42 → has in-review   (ALLOW)
  #       PR 99 → no in-review    (BLOCK)
  #       PR *  → no in-review    (BLOCK, default)
  # This avoids real network calls and makes the test fully hermetic.
  # -------------------------------------------------------------------------
  mock_label_cmd() {
    local pr_num="$1"
    if [[ "$pr_num" == "42" ]]; then
      printf '["in-review","enhancement"]'
    elif [[ "$pr_num" == "7" ]]; then
      printf '["enhancement","in-review","priority:high"]'
    else
      printf '["enhancement","backlog"]'
    fi
  }
  export -f mock_label_cmd
  export CLAUDE_HOOK_GH_LABELS_CMD="mock_label_cmd"

  run_case() {
    local label="$1"
    local cmd="$2"
    local expect="$3"   # "block" or "allow"

    local payload
    # Use jq to build the JSON so that special characters (double quotes, etc.)
    # in $cmd are properly escaped — printf %s would produce invalid JSON for
    # commands that contain literal double-quote characters.
    payload="$(jq -cn --arg cmd "$cmd" '{"tool_name":"Bash","tool_input":{"command":$cmd}}')"

    local exit_code=0
    printf '%s' "$payload" | bash "$SCRIPT" >/dev/null 2>&1 || exit_code=$?

    local actual
    if [[ "$exit_code" -eq 2 ]]; then
      actual="block"
    else
      actual="allow"
    fi

    if [[ "$actual" == "$expect" ]]; then
      printf '  PASS  %-60s  (%s)\n' "$label" "$expect"
      PASS=$(( PASS + 1 ))
    else
      printf '  FAIL  %-60s  expected=%s actual=%s\n' "$label" "$expect" "$actual"
      FAIL=$(( FAIL + 1 ))
    fi
  }

  echo "=== pr-merge-requires-in-review.sh --self-test ==="
  echo ""
  echo "--- SHOULD BLOCK (exit 2) ---"

  # PR without in-review — various command forms
  run_case "gh pr merge 5  (no in-review)"                 "gh pr merge 5"                           "block"
  run_case "gh pr merge --squash 5  (flag before num)"     "gh pr merge --squash 5"                  "block"
  run_case "gh pr merge 5 --squash  (flag after num)"      "gh pr merge 5 --squash"                  "block"
  run_case "gh pr merge 5 --squash --delete-branch"        "gh pr merge 5 --squash --delete-branch"  "block"
  run_case "gh pr merge '5'  (single-quoted number)"       "gh pr merge '5'"                         "block"
  run_case 'gh pr merge "5"  (double-quoted number)'       'gh pr merge "5"'                         "block"
  run_case "compound: cd /tmp && gh pr merge 5"            "cd /tmp && gh pr merge 5"                "block"
  run_case "URL form: gh pr merge .../pull/5"              "gh pr merge https://github.com/owner/repo/pull/5"  "block"

  echo ""
  echo "--- SHOULD ALLOW (exit 0) ---"

  # PR with in-review — various command forms (PR #42 and #7 are mocked with in-review)
  run_case "gh pr merge 42  (has in-review)"               "gh pr merge 42"                          "allow"
  run_case "gh pr merge --squash 42  (in-review, flag)"    "gh pr merge --squash 42"                 "allow"
  run_case "gh pr merge 7 --squash  (in-review, flag)"     "gh pr merge 7 --squash"                  "allow"

  # Non-merge gh subcommands — must pass through untouched
  run_case "gh pr view 5  (not a merge command)"           "gh pr view 5"                            "allow"
  run_case "gh pr create  (not a merge command)"           "gh pr create --title x --body y"         "allow"
  run_case "gh issue close 5  (non-pr command)"            "gh issue close 5"                        "allow"
  run_case "gh issue edit 5 --add-label in-review"         "gh issue edit 5 --add-label in-review"   "allow"
  run_case "ls -la  (non-gh command)"                      "ls -la"                                  "allow"
  run_case "git push origin feat/11-branch"                "git push origin feat/11-branch"          "allow"

  # Bypass escape hatch
  CLAUDE_HOOK_BYPASS=1 run_case "CLAUDE_HOOK_BYPASS=1 with blocked PR" "gh pr merge 5"              "allow"

  echo ""
  echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
  [[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
fi

# ---------------------------------------------------------------------------
# Normal hook mode
# ---------------------------------------------------------------------------

# --- Bypass for ops emergencies ---
if [[ "${CLAUDE_HOOK_BYPASS:-}" == "1" ]]; then
  exit 0
fi

# --- Read stdin ---
INPUT="$(cat)"

# Require jq; fail open (allow) if unavailable so the hook is never itself the blocker
if ! command -v jq &>/dev/null; then
  echo "[pr-merge-requires-in-review] WARNING: jq not found — hook skipped. Install jq to enable protection." >&2
  exit 0
fi

COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')"

# If we couldn't parse a command, allow through (don't break unrelated tool calls)
if [[ -z "$COMMAND" ]]; then
  exit 0
fi

# ---------------------------------------------------------------------------
# Detection: does this command contain `gh pr merge`?
#
# Strategy: scan every semicolon/&&/||-separated segment of the compound
# command for a token sequence matching `gh pr merge`. This handles:
#   - Simple: gh pr merge 5
#   - Compound: cd /tmp && gh pr merge 5
#   - Piped: echo foo | gh pr merge 5  (pathological but handled)
#
# We use grep -qE rather than bash regex to avoid bash ERE portability issues.
# ---------------------------------------------------------------------------
if ! printf '%s' "$COMMAND" | command grep -qE '\bgh\b.*\bpr\b.*\bmerge\b'; then
  # Not a gh pr merge call — allow through
  exit 0
fi

# ---------------------------------------------------------------------------
# Extract the PR number from the `gh pr merge` invocation.
#
# Supported forms:
#   gh pr merge 5
#   gh pr merge --squash 5
#   gh pr merge 5 --squash
#   gh pr merge 5 --squash --delete-branch
#   gh pr merge '5'              (single-quoted — strip quotes)
#   gh pr merge "5"              (double-quoted — strip quotes)
#   gh pr merge https://github.com/owner/repo/pull/5  (URL — extract trailing digits)
#   cd /tmp && gh pr merge 5    (compound command — grep finds the merge segment)
#
# Algorithm:
#   1. Extract the segment containing `gh pr merge` (handles compound commands).
#   2. Strip everything up to and including `merge`.
#   3. Walk remaining tokens (split on whitespace):
#      a. Skip flag tokens (start with `-`).
#      b. For the first non-flag token:
#         - If it looks like a URL (contains "pull/"), extract the trailing digits.
#         - If it's a bare integer (possibly quoted), strip quotes and use it.
#         - Otherwise, it's unrecognised — fail open (allow) and warn.
# ---------------------------------------------------------------------------

# Step 1: isolate the gh pr merge segment from a compound command.
# grep -oE extracts the matching portion; head -1 takes the first match.
MERGE_SEGMENT="$(printf '%s' "$COMMAND" | command grep -oE '\bgh\b[^;&|]*\bpr\b[^;&|]*\bmerge\b.*' | head -1)"

if [[ -z "$MERGE_SEGMENT" ]]; then
  # Couldn't isolate segment — fail open
  exit 0
fi

# Step 2: strip everything up to and including "merge "
AFTER_MERGE="${MERGE_SEGMENT#*merge}"
# Remove leading whitespace
AFTER_MERGE="${AFTER_MERGE#"${AFTER_MERGE%%[! ]*}"}"

# Step 3: walk tokens to find the PR number
PR_NUM=""
for token in $AFTER_MERGE; do
  # Skip flag arguments (--squash, --delete-branch, -m, etc.)
  if [[ "$token" == -* ]]; then
    continue
  fi

  # Strip surrounding shell quotes (same technique as hook 1 / PR #17 commit 81d300d)
  # Example: "'5'" → "5";  '"42"' → "42"
  if [[ ( "$token" == \'*\' ) || ( "$token" == \"*\" ) ]]; then
    token="${token:1:${#token}-2}"
  fi

  # URL form: https://github.com/owner/repo/pull/5 — extract trailing integer
  if printf '%s' "$token" | command grep -qE 'pull/[0-9]+'; then
    PR_NUM="$(printf '%s' "$token" | command grep -oE 'pull/[0-9]+' | command grep -oE '[0-9]+$')"
    break
  fi

  # Bare integer
  if printf '%s' "$token" | command grep -qE '^[0-9]+$'; then
    PR_NUM="$token"
    break
  fi

  # First non-flag, non-numeric token — could be a branch name or "HEAD".
  # gh pr merge also accepts a branch name or "HEAD" to identify the PR.
  # We can't look up labels without a PR number or URL, so fail open and warn.
  echo "[pr-merge-requires-in-review] WARNING: Could not extract a numeric PR number from: $MERGE_SEGMENT" >&2
  echo "[pr-merge-requires-in-review] Allowing through — verify the PR carries the in-review label manually." >&2
  exit 0
done

if [[ -z "$PR_NUM" ]]; then
  # No number found (e.g., bare `gh pr merge` with no args) — allow through
  exit 0
fi

# ---------------------------------------------------------------------------
# Query the PR's labels.
#
# In --self-test mode CLAUDE_HOOK_GH_LABELS_CMD is set to "mock_label_cmd",
# which is a bash function exported into the environment. In normal mode it is
# unset and we call `gh pr view` directly.
# ---------------------------------------------------------------------------
fetch_labels() {
  local pr_num="$1"
  if [[ -n "${CLAUDE_HOOK_GH_LABELS_CMD:-}" ]]; then
    # Self-test mock: call the stub function/command with the PR number
    bash -c "${CLAUDE_HOOK_GH_LABELS_CMD} ${pr_num}"
  else
    gh pr view "$pr_num" --json labels --jq '[.labels[].name]' 2>/dev/null || echo "[]"
  fi
}

LABELS_JSON="$(fetch_labels "$PR_NUM")"

# Check if `in-review` is present in the label list
if printf '%s' "$LABELS_JSON" | jq -e 'map(select(. == "in-review")) | length > 0' >/dev/null 2>&1; then
  # in-review found — allow
  exit 0
fi

# ---------------------------------------------------------------------------
# BLOCKED — emit a clear error message
# ---------------------------------------------------------------------------
cat >&2 <<EOF
[HOOK BLOCKED] \`gh pr merge ${PR_NUM}\` was intercepted: the PR does not carry the \`in-review\` label.

  Rule: SDLC.md Step 5 — "Apply in-review label (your signal; Code Reviewer
        watches for it). … Code Reviewer merges. Always."

  PR #${PR_NUM} current labels: ${LABELS_JSON}

  Required steps before merging:
    1. Ensure your PR is ready for review (all commits pushed, CI green).
    2. Apply the \`in-review\` label:
         gh pr edit ${PR_NUM} --add-label in-review
    3. Notify or wait for the Code Reviewer to review and merge.
    4. Do NOT merge your own PR.

  Label ownership reference: .claude/skills/label-discipline/

  Override (ops emergency only): set CLAUDE_HOOK_BYPASS=1 in your shell,
  then restart Claude Code. Document the bypass reason in your PR body.
EOF
exit 2

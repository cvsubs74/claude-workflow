#!/usr/bin/env bash
# no-direct-push-main.sh — Hook 1 of 5
#
# PreToolUse / Bash hook: block direct git commit/push to main.
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
#   Block:   echo '{"tool_name":"Bash","tool_input":{"command":"git push origin main"}}' | bash no-direct-push-main.sh
#   Block:   echo '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"fix\""}}' | bash no-direct-push-main.sh
#   Allow:   echo '{"tool_name":"Bash","tool_input":{"command":"git push origin feat/9-my-branch"}}' | bash no-direct-push-main.sh
#
# Operator override: set CLAUDE_HOOK_BYPASS=1 to skip all checks.
# See .claude/hooks/README.md for full escape-hatch documentation.

set -euo pipefail

# --- Bypass for ops emergencies ---
if [[ "${CLAUDE_HOOK_BYPASS:-}" == "1" ]]; then
  exit 0
fi

# --- Read stdin ---
INPUT="$(cat)"

# Require jq; fail open (allow) if unavailable so the hook is never itself the blocker
if ! command -v jq &>/dev/null; then
  echo "[no-direct-push-main] WARNING: jq not found — hook skipped. Install jq to enable protection." >&2
  exit 0
fi

COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')"

# If we couldn't parse a command, allow through (don't break unrelated tool calls)
if [[ -z "$COMMAND" ]]; then
  exit 0
fi

# --- Check 1: git push origin main / master ---
# Matches:
#   git push origin main
#   git push origin master
#   git push --force origin main
#   git push --force-with-lease origin main
#   git push -f origin main
# Does NOT match:
#   git push origin feat/9-hook-no-direct-push-main
#   git push upstream main  (different remote — out of scope per issue #9 non-goals)
if printf '%s' "$COMMAND" | command grep -qE 'git\s+push\b.*\borigin\b.*(^|\s)(main|master)(\s|$)'; then
  cat >&2 <<'EOF'
[HOOK BLOCKED] Direct push to main/master is not allowed.

  Rule: SDLC.md Step 2 — "No direct commits to the default branch.
        Every change goes through a PR."

  Required workflow:
    1. Create a feature branch: git checkout -b feat/<issue>-<slug>
    2. Push the branch:         git push origin feat/<issue>-<slug>
    3. Open a PR on GitHub.

  Operator emergency override: set CLAUDE_HOOK_BYPASS=1 in your shell,
  then restart Claude Code. Document the bypass reason in your commit or PR.
EOF
  exit 2
fi

# --- Check 2: git commit while on main / master ---
# Determine the current branch from git; if we're not in a git repo, allow through.
CURRENT_BRANCH=""
if git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
  CURRENT_BRANCH="$(git symbolic-ref --short HEAD 2>/dev/null || echo "")"
fi

if [[ "$CURRENT_BRANCH" == "main" || "$CURRENT_BRANCH" == "master" ]]; then
  if printf '%s' "$COMMAND" | command grep -qE '^\s*git\s+commit\b'; then
    cat >&2 <<'EOF'
[HOOK BLOCKED] Direct commit to main/master is not allowed.

  Rule: SDLC.md Step 2 — "No direct commits to the default branch.
        Every change goes through a PR."

  You are currently on branch: main (or master)

  Required workflow:
    1. Create a feature branch: git checkout -b feat/<issue>-<slug>
    2. Make your commits there.
    3. Push + open a PR on GitHub.

  Operator emergency override: set CLAUDE_HOOK_BYPASS=1 in your shell,
  then restart Claude Code. Document the bypass reason in your commit or PR.
EOF
    exit 2
  fi
fi

# --- All checks passed ---
exit 0

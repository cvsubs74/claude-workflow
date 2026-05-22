#!/usr/bin/env bash
# session-start-doc-check.sh — Hook 4 of 5
#
# SessionStart hook: sanity-check that required cold-start docs exist.
#
# Claude Code invokes this script at session start. It receives a JSON
# object on stdin with session metadata (shape may vary by Claude Code version;
# we parse defensively and ignore unknown fields). Example shape:
#
#   {
#     "session_id": "<uuid>",
#     "transcript_path": "/path/to/transcript"
#   }
#
# This hook NEVER BLOCKS — it is a sanity check only. Exit code is always 0.
# Blocking a SessionStart hook would brick every session; do not change this.
#
# Required cold-start docs (CLAUDE.md lists these):
#   - CLAUDE.md   (required — agent operating instructions)
#   - ETHOS.md    (required — the three principles that override all defaults)
#   - SDLC.md     (required — branch naming, PR workflow, label scheme)
#   - docs/ARCHITECTURE.md (optional — recommended; absence is informational only)
#
# Exit codes:
#   0  — always (this hook never blocks)
#
# Tests live in tests/test_hooks.sh (run via bash tests/run.sh).
#
# Test-root override (for tests and CI):
#   --test-root <dir>            use <dir> as the repo root instead of $PWD
#   CLAUDE_HOOK_TEST_ROOT=<dir>  same, via environment variable
#   (--test-root flag takes precedence over env var)
#
# Operator override: set CLAUDE_HOOK_BYPASS=1 to skip all checks.
# See .claude/hooks/README.md for full escape-hatch documentation.

set -euo pipefail


# ---------------------------------------------------------------------------
# Parse --test-root flag (must come before bypass check so tests work)
# ---------------------------------------------------------------------------
REPO_ROOT="${CLAUDE_HOOK_TEST_ROOT:-}"

if [[ "${1:-}" == "--test-root" ]]; then
  if [[ -z "${2:-}" ]]; then
    echo "[session-start-doc-check] ERROR: --test-root requires a directory argument." >&2
    exit 0   # never block
  fi
  REPO_ROOT="$2"
  shift 2
fi

# Fall back to current working directory if no override was provided
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$PWD"
fi

# ---------------------------------------------------------------------------
# Normal hook mode
# ---------------------------------------------------------------------------

# --- Bypass for ops emergencies ---
if [[ "${CLAUDE_HOOK_BYPASS:-}" == "1" ]]; then
  exit 0
fi

# --- Read and discard stdin (required by the hooks contract; parse defensively) ---
INPUT="$(cat)"

# Parse session_id for potential future use (fail open if jq unavailable)
SESSION_ID=""
if command -v jq &>/dev/null; then
  SESSION_ID="$(printf '%s' "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || true)"
fi

# ---------------------------------------------------------------------------
# Check required cold-start docs
# ---------------------------------------------------------------------------

REQUIRED_DOCS=("CLAUDE.md" "ETHOS.md" "SDLC.md")
OPTIONAL_DOCS=("docs/ARCHITECTURE.md")
WARNINGS_EMITTED=0

for doc in "${REQUIRED_DOCS[@]}"; do
  if [[ ! -f "$REPO_ROOT/$doc" ]]; then
    echo "[HOOK WARNING] Required cold-start doc missing: ${doc}." \
         "Propose creating it before acting (see CLAUDE.md)." >&2
    WARNINGS_EMITTED=$(( WARNINGS_EMITTED + 1 ))
  fi
done

for doc in "${OPTIONAL_DOCS[@]}"; do
  if [[ ! -f "$REPO_ROOT/$doc" ]]; then
    echo "[HOOK INFO] Optional cold-start doc not found: ${doc}." \
         "Consider creating it to document system shape (see CLAUDE.md)." >&2
  fi
done

# ---------------------------------------------------------------------------
# This hook NEVER BLOCKS — always exit 0
# ---------------------------------------------------------------------------
exit 0

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
# Smoke-test examples (echo simulated SessionStart payload):
#   echo '{"session_id":"abc123","transcript_path":"/tmp/t.json"}' | bash session-start-doc-check.sh
#
# Self-test: run with --self-test to verify all cases pass:
#   bash session-start-doc-check.sh --self-test
#
# Test-root override (for self-test and CI):
#   --test-root <dir>            use <dir> as the repo root instead of $PWD
#   CLAUDE_HOOK_TEST_ROOT=<dir>  same, via environment variable
#   (--test-root flag takes precedence over env var)
#
# Operator override: set CLAUDE_HOOK_BYPASS=1 to skip all checks.
# See .claude/hooks/README.md for full escape-hatch documentation.

set -euo pipefail

# ---------------------------------------------------------------------------
# Self-test mode
# ---------------------------------------------------------------------------
if [[ "${1:-}" == "--self-test" ]]; then
  SCRIPT="$0"
  PASS=0
  FAIL=0

  # Build a minimal SessionStart JSON payload using jq
  make_payload() {
    jq -cn '{"session_id":"test-session-001","transcript_path":"/tmp/test-transcript.json"}'
  }

  # run_case <label> <test_root_dir> <expected_warnings> [env_overrides...]
  # expected_warnings: space-separated list of substrings that MUST appear in stderr.
  #   Use "" (empty string) for "no warnings expected".
  # If the first element of expected_warnings is "BYPASS", treat as bypass test.
  run_case() {
    local label="$1"
    local test_root="$2"
    local expected_warnings="$3"
    shift 3
    local extra_env=("$@")

    local payload
    payload="$(make_payload)"

    # Capture stderr; run with any extra env overrides applied to the bash subprocess.
    # We use a subshell so that env vars in extra_env are exported only into the
    # child bash process (not into the current test harness).
    local stderr_out
    local exit_code=0
    stderr_out="$(
      (
        # Export each extra env var into this subshell
        for kv in "${extra_env[@]+"${extra_env[@]}"}"; do
          export "$kv"
        done
        printf '%s' "$payload" | bash "$SCRIPT" --test-root "$test_root" 2>&1 >/dev/null
      )
    )" || exit_code=$?

    # This hook must always exit 0
    if [[ "$exit_code" -ne 0 ]]; then
      printf '  FAIL  %-60s  (hook exited %d — must always exit 0)\n' "$label" "$exit_code"
      FAIL=$(( FAIL + 1 ))
      return
    fi

    # Check expected warnings
    local ok=1
    if [[ "$expected_warnings" == "BYPASS" ]]; then
      # Bypass: expect completely silent output
      if [[ -n "$stderr_out" ]]; then
        printf '  FAIL  %-60s  (expected silent, got: %s)\n' "$label" "$stderr_out"
        ok=0
      fi
    elif [[ -z "$expected_warnings" ]]; then
      # No warnings expected
      if [[ -n "$stderr_out" ]]; then
        printf '  FAIL  %-60s  (unexpected output: %s)\n' "$label" "$stderr_out"
        ok=0
      fi
    else
      # Each item in expected_warnings must appear in stderr
      for pattern in $expected_warnings; do
        if ! printf '%s' "$stderr_out" | grep -q "$pattern"; then
          printf '  FAIL  %-60s  (missing pattern "%s" in output)\n' "$label" "$pattern"
          ok=0
        fi
      done
    fi

    if [[ "$ok" -eq 1 ]]; then
      printf '  PASS  %-60s\n' "$label"
      PASS=$(( PASS + 1 ))
    else
      FAIL=$(( FAIL + 1 ))
    fi
  }

  echo "=== session-start-doc-check.sh --self-test ==="
  echo ""

  # --- Helper: create temp dirs with various file combinations ---
  TMPDIR_BASE="$(mktemp -d)"
  trap 'rm -rf "$TMPDIR_BASE"' EXIT

  make_root() {
    local name="$1"
    shift
    local dir="$TMPDIR_BASE/$name"
    mkdir -p "$dir/docs"
    for f in "$@"; do
      touch "$dir/$f"
    done
    echo "$dir"
  }

  # Case 1: All required files present (CLAUDE.md, ETHOS.md, SDLC.md + ARCHITECTURE)
  ROOT_ALL="$(make_root "all" CLAUDE.md ETHOS.md SDLC.md docs/ARCHITECTURE.md)"
  # Case 2: ETHOS.md missing
  ROOT_NO_ETHOS="$(make_root "no_ethos" CLAUDE.md SDLC.md docs/ARCHITECTURE.md)"
  # Case 3: SDLC.md missing
  ROOT_NO_SDLC="$(make_root "no_sdlc" CLAUDE.md ETHOS.md docs/ARCHITECTURE.md)"
  # Case 4: CLAUDE.md missing
  ROOT_NO_CLAUDE="$(make_root "no_claude" ETHOS.md SDLC.md docs/ARCHITECTURE.md)"
  # Case 5: All three required missing (only docs/ARCHITECTURE.md present)
  ROOT_NONE="$(make_root "none" docs/ARCHITECTURE.md)"
  # Case 6: Only docs/ARCHITECTURE.md missing (all required present)
  ROOT_NO_ARCH="$(make_root "no_arch" CLAUDE.md ETHOS.md SDLC.md)"
  # Case 7: Nothing at all (empty root — all four missing)
  ROOT_EMPTY="$(make_root "empty")"

  echo "--- REQUIRED FILES PRESENT / ABSENT ---"
  run_case "all required files present — no warnings"                    "$ROOT_ALL"       ""
  run_case "ETHOS.md missing — warning for ETHOS.md"                    "$ROOT_NO_ETHOS"  "ETHOS.md"
  run_case "SDLC.md missing — warning for SDLC.md"                      "$ROOT_NO_SDLC"   "SDLC.md"
  run_case "CLAUDE.md missing — warning for CLAUDE.md"                  "$ROOT_NO_CLAUDE" "CLAUDE.md"
  run_case "all three required missing — three warnings"                 "$ROOT_NONE"      "CLAUDE.md ETHOS.md SDLC.md"
  run_case "docs/ARCHITECTURE.md missing alone — info note not warning"  "$ROOT_NO_ARCH"   "ARCHITECTURE.md"

  echo ""
  echo "--- BYPASS ---"
  run_case "CLAUDE_HOOK_BYPASS=1 — silent regardless of missing files"   "$ROOT_EMPTY"     "BYPASS"  "CLAUDE_HOOK_BYPASS=1"

  echo ""
  echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
  [[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
fi

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

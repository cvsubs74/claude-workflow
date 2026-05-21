#!/usr/bin/env bash
# tests/test_hooks.sh — all hook scenario tests.
#
# Migrated from the per-hook --self-test blocks. One section per hook.
# Run via tests/run.sh, not directly (lib.sh is in the same dir).
#
# Hook 4 (session-start-doc-check) doesn't use the run_case payload pattern
# because it's a SessionStart hook driven by filesystem state — that section
# embeds its own small harness.

# shellcheck source=./lib.sh
source "$(dirname "$0")/lib.sh"

# ===========================================================================
# Hook 1 — no-direct-push-main.sh (25 cases)
# ===========================================================================
echo "--- HOOK 1: no-direct-push-main.sh ---"
HOOK="$HOOKS_DIR/no-direct-push-main.sh"

# Basic forms
run_case "$HOOK" "git push origin main"                  "git push origin main"                   "block"
run_case "$HOOK" "git push origin master"                "git push origin master"                 "block"
run_case "$HOOK" "git push --force origin main"          "git push --force origin main"           "block"
run_case "$HOOK" "git push -f origin main"               "git push -f origin main"                "block"
run_case "$HOOK" "git push -u origin main"               "git push -u origin main"                "block"

# Refspec bypass forms
run_case "$HOOK" "git push origin HEAD:main"             "git push origin HEAD:main"              "block"
run_case "$HOOK" "git push origin refs/heads/main"       "git push origin refs/heads/main"        "block"
run_case "$HOOK" "git push origin main:main"             "git push origin main:main"              "block"
run_case "$HOOK" "git push origin +main"                 "git push origin +main"                  "block"
run_case "$HOOK" "git push origin :main (delete remote)" "git push origin :main"                  "block"
run_case "$HOOK" "git push origin +main:main"            "git push origin +main:main"             "block"
run_case "$HOOK" "git push origin +refs/heads/main"      "git push origin +refs/heads/main"       "block"
run_case "$HOOK" "git push origin HEAD:refs/heads/main"  "git push origin HEAD:refs/heads/main"   "block"

# Quoted-arg bypass forms
run_case "$HOOK" "git push 'origin' 'main' (single-quoted)"        "git push 'origin' 'main'"                  "block"
run_case "$HOOK" 'git push "origin" "main" (double-quoted)'        'git push "origin" "main"'                  "block"
run_case "$HOOK" "git push 'origin' 'HEAD:main' (quoted+refspec)"  "git push 'origin' 'HEAD:main'"             "block"
run_case "$HOOK" 'git push "origin" "HEAD:refs/heads/main"'        'git push "origin" "HEAD:refs/heads/main"'  "block"

# Allow paths
run_case "$HOOK" "git push origin feat/9-branch"           "git push origin feat/9-branch"     "allow"
run_case "$HOOK" "git push origin mainline (no fp)"        "git push origin mainline"          "allow"
run_case "$HOOK" "git push origin feat/main-fix"           "git push origin feat/main-fix"     "allow"
run_case "$HOOK" "git push upstream main (different remote)" "git push upstream main"          "allow"
run_case "$HOOK" "git push 'origin' 'feat/x' (quoted, allowed)" "git push 'origin' 'feat/x'"   "allow"
run_case "$HOOK" "git commit -m fix (on feature branch)"   "git commit -m fix"                 "allow"
run_case "$HOOK" "ls -la (non-git command)"                "ls -la"                            "allow"
CLAUDE_HOOK_BYPASS=1 run_case "$HOOK" "bypass via CLAUDE_HOOK_BYPASS=1" "git push origin main" "allow"

# ===========================================================================
# Hook 2 — restricted-label-ownership.sh (30 cases)
# ===========================================================================
echo ""
echo "--- HOOK 2: restricted-label-ownership.sh ---"
HOOK="$HOOKS_DIR/restricted-label-ownership.sh"

# PM-only labels — non-PM agents blocked
run_case "$HOOK" "dev adds priority:high"           "gh issue edit 5 --add-label priority:high"     "block" "dev-agent"
run_case "$HOOK" "dev adds prioritized"             "gh issue edit 5 --add-label prioritized"       "block" "dev-agent"
run_case "$HOOK" "qa adds priority:medium"          "gh issue edit 5 --add-label priority:medium"   "block" "qa-agent"
run_case "$HOOK" "triage adds priority:low"         "gh issue edit 5 --add-label priority:low"      "block" "triage-agent"
run_case "$HOOK" "dev adds pm label"                "gh issue edit 5 --add-label pm"                "block" "dev-agent"
run_case "$HOOK" "dev removes prioritized"          "gh issue edit 5 --remove-label prioritized"    "block" "dev-agent"

# QA-only labels — non-QA agents blocked
run_case "$HOOK" "dev adds resolved"                "gh issue edit 5 --add-label resolved"          "block" "dev-agent"
run_case "$HOOK" "pm adds resolved"                 "gh issue edit 5 --add-label resolved"          "block" "pm-agent"
run_case "$HOOK" "dev adds qa label"                "gh issue edit 5 --add-label qa"                "block" "dev-agent"
run_case "$HOOK" "pm adds qa label"                 "gh pr edit 5 --add-label qa"                   "block" "pm-agent"

# in-review — dev-only (even CR is blocked)
run_case "$HOOK" "pm adds in-review"                "gh issue edit 5 --add-label in-review"         "block" "pm-agent"
run_case "$HOOK" "qa adds in-review"                "gh pr edit 5 --add-label in-review"            "block" "qa-agent"
run_case "$HOOK" "triage removes in-review"         "gh pr edit 5 --remove-label in-review"         "block" "triage-agent"
run_case "$HOOK" "code-reviewer adds in-review"     "gh pr edit 5 --add-label in-review"            "block" "code-reviewer-agent"
run_case "$HOOK" "code-reviewer removes in-review"  "gh pr edit 5 --remove-label in-review"         "block" "code-reviewer-agent"

# PM adding its own labels
run_case "$HOOK" "pm adds priority:high (owner)"    "gh issue edit 5 --add-label priority:high"     "allow" "pm-agent"
run_case "$HOOK" "pm adds prioritized (owner)"      "gh issue edit 5 --add-label prioritized"       "allow" "pm-agent"
run_case "$HOOK" "pm adds priority:medium (owner)"  "gh issue edit 5 --add-label priority:medium"   "allow" "pm-agent"
run_case "$HOOK" "pm adds priority:low (owner)"     "gh issue edit 5 --add-label priority:low"      "allow" "pm-agent"
run_case "$HOOK" "pm adds pm label (owner)"         "gh issue edit 5 --add-label pm"                "allow" "pm-agent"

# QA adding its own labels
run_case "$HOOK" "qa adds resolved (owner)"         "gh issue edit 5 --add-label resolved"          "allow" "qa-agent"
run_case "$HOOK" "qa adds qa label (owner)"         "gh issue edit 5 --add-label qa"                "allow" "qa-agent"

# Dev adding in-review (owner)
run_case "$HOOK" "dev adds in-review (owner)"       "gh pr edit 5 --add-label in-review"            "allow" "dev-agent"

# Unrestricted labels — anyone may apply
run_case "$HOOK" "dev adds enhancement"             "gh issue edit 5 --add-label enhancement"       "allow" "dev-agent"
run_case "$HOOK" "dev adds bug"                     "gh issue edit 5 --add-label bug"               "allow" "dev-agent"
run_case "$HOOK" "qa adds backlog"                  "gh issue edit 5 --add-label backlog"           "allow" "qa-agent"

# No agent context — fail open
run_case "$HOOK" "no agent context (fail-open)"     "gh issue edit 5 --add-label prioritized"       "allow"

# Bypass + non-gh
CLAUDE_HOOK_BYPASS=1 run_case "$HOOK" "bypass via CLAUDE_HOOK_BYPASS=1" "gh issue edit 5 --add-label prioritized" "allow" "dev-agent"
run_case "$HOOK" "git push (non-gh)"                "git push origin feat/10"                       "allow" "dev-agent"
run_case "$HOOK" "ls -la (non-gh)"                  "ls -la"                                        "allow" "dev-agent"

# ===========================================================================
# Hook 3 — pr-merge-requires-in-review.sh (18 cases)
# ===========================================================================
echo ""
echo "--- HOOK 3: pr-merge-requires-in-review.sh ---"
HOOK="$HOOKS_DIR/pr-merge-requires-in-review.sh"

# Stub the gh pr view call via the script-file stub fixture
export CLAUDE_HOOK_GH_LABELS_CMD="$REPO_ROOT/tests/fixtures/gh-labels-stub.sh"

# PR without in-review — various command forms
run_case "$HOOK" "gh pr merge 5 (no in-review)"            "gh pr merge 5"                                            "block"
run_case "$HOOK" "gh pr merge --squash 5 (flag before)"    "gh pr merge --squash 5"                                   "block"
run_case "$HOOK" "gh pr merge 5 --squash (flag after)"     "gh pr merge 5 --squash"                                   "block"
run_case "$HOOK" "gh pr merge 5 --squash --delete-branch"  "gh pr merge 5 --squash --delete-branch"                   "block"
run_case "$HOOK" "gh pr merge '5' (single-quoted num)"     "gh pr merge '5'"                                          "block"
run_case "$HOOK" 'gh pr merge "5" (double-quoted num)'     'gh pr merge "5"'                                          "block"
run_case "$HOOK" "compound: cd /tmp && gh pr merge 5"      "cd /tmp && gh pr merge 5"                                 "block"
run_case "$HOOK" "URL form: gh pr merge .../pull/5"        "gh pr merge https://github.com/owner/repo/pull/5"         "block"

# PR with in-review (mock PR #42, #7)
run_case "$HOOK" "gh pr merge 42 (has in-review)"          "gh pr merge 42"                                           "allow"
run_case "$HOOK" "gh pr merge --squash 42"                 "gh pr merge --squash 42"                                  "allow"
run_case "$HOOK" "gh pr merge 7 --squash"                  "gh pr merge 7 --squash"                                   "allow"

# Non-merge gh subcommands
run_case "$HOOK" "gh pr view 5 (not merge)"                "gh pr view 5"                                             "allow"
run_case "$HOOK" "gh pr create (not merge)"                "gh pr create --title x --body y"                          "allow"
run_case "$HOOK" "gh issue close 5"                        "gh issue close 5"                                         "allow"
run_case "$HOOK" "gh issue edit 5 --add-label in-review"   "gh issue edit 5 --add-label in-review"                    "allow"
run_case "$HOOK" "ls -la (non-gh)"                         "ls -la"                                                   "allow"
run_case "$HOOK" "git push origin feat/11-branch"          "git push origin feat/11-branch"                           "allow"

CLAUDE_HOOK_BYPASS=1 run_case "$HOOK" "bypass with blocked PR"  "gh pr merge 5"                                       "allow"

unset CLAUDE_HOOK_GH_LABELS_CMD

# ===========================================================================
# Hook 4 — session-start-doc-check.sh (7 cases)
# This hook uses --test-root + filesystem-driven assertions (not payload-
# based exit codes), so it embeds its own small harness.
# ===========================================================================
echo ""
echo "--- HOOK 4: session-start-doc-check.sh ---"
HOOK="$HOOKS_DIR/session-start-doc-check.sh"

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

make_root() {
  local name="$1"; shift
  local dir="$TMPDIR_BASE/$name"
  mkdir -p "$dir/docs"
  for f in "$@"; do touch "$dir/$f"; done
  echo "$dir"
}

# run_case_session <label> <test_root> <expected_patterns_or_BYPASS> [env...]
# Empty string for expected_patterns = expect no stderr output at all.
run_case_session() {
  local label="$1"
  local test_root="$2"
  local expected="$3"
  shift 3
  local extra_env=("$@")

  local payload
  payload="$(jq -cn '{"session_id":"test","transcript_path":"/tmp/t"}')"

  local stderr_out exit_code=0
  stderr_out="$(
    (
      for kv in "${extra_env[@]+"${extra_env[@]}"}"; do export "$kv"; done
      printf '%s' "$payload" | bash "$HOOK" --test-root "$test_root" 2>&1 >/dev/null
    )
  )" || exit_code=$?

  if [[ "$exit_code" -ne 0 ]]; then
    printf '  FAIL  %-60s  (must exit 0; got %d)\n' "$label" "$exit_code"
    FAIL=$(( FAIL + 1 )); return
  fi

  local ok=1
  if [[ "$expected" == "BYPASS" ]]; then
    [[ -n "$stderr_out" ]] && { printf '  FAIL  %-60s  (expected silent, got: %s)\n' "$label" "$stderr_out"; ok=0; }
  elif [[ -z "$expected" ]]; then
    [[ -n "$stderr_out" ]] && { printf '  FAIL  %-60s  (unexpected output: %s)\n' "$label" "$stderr_out"; ok=0; }
  else
    for p in $expected; do
      printf '%s' "$stderr_out" | grep -q "$p" || { printf '  FAIL  %-60s  (missing "%s")\n' "$label" "$p"; ok=0; }
    done
  fi

  if [[ "$ok" -eq 1 ]]; then
    printf '  PASS  %s\n' "$label"
    PASS=$(( PASS + 1 ))
  else
    FAIL=$(( FAIL + 1 ))
  fi
}

ROOT_ALL="$(make_root all CLAUDE.md ETHOS.md SDLC.md docs/ARCHITECTURE.md)"
ROOT_NO_ETHOS="$(make_root no_ethos CLAUDE.md SDLC.md docs/ARCHITECTURE.md)"
ROOT_NO_SDLC="$(make_root no_sdlc CLAUDE.md ETHOS.md docs/ARCHITECTURE.md)"
ROOT_NO_CLAUDE="$(make_root no_claude ETHOS.md SDLC.md docs/ARCHITECTURE.md)"
ROOT_NONE="$(make_root none docs/ARCHITECTURE.md)"
ROOT_NO_ARCH="$(make_root no_arch CLAUDE.md ETHOS.md SDLC.md)"
ROOT_EMPTY="$(make_root empty)"

run_case_session "all required present (no warnings)"        "$ROOT_ALL"        ""
run_case_session "ETHOS.md missing (warning)"                "$ROOT_NO_ETHOS"   "ETHOS.md"
run_case_session "SDLC.md missing (warning)"                 "$ROOT_NO_SDLC"    "SDLC.md"
run_case_session "CLAUDE.md missing (warning)"               "$ROOT_NO_CLAUDE"  "CLAUDE.md"
run_case_session "all three required missing (warnings)"     "$ROOT_NONE"       "CLAUDE.md ETHOS.md SDLC.md"
run_case_session "docs/ARCHITECTURE.md missing (info only)"  "$ROOT_NO_ARCH"    "ARCHITECTURE.md"
run_case_session "CLAUDE_HOOK_BYPASS=1 (silent)"             "$ROOT_EMPTY"      "BYPASS" "CLAUDE_HOOK_BYPASS=1"

# ===========================================================================
# Hook 5 — pr-body-closes-check.sh (19 cases)
# Uses run_case_warn because Hook 5 always exits 0 — assertion is whether
# [HOOK WARNING] appears in stderr.
# ===========================================================================
echo ""
echo "--- HOOK 5: pr-body-closes-check.sh ---"
HOOK="$HOOKS_DIR/pr-body-closes-check.sh"

# Temp files for --body-file cases
TMP_WITH_CLOSES="$(mktemp)"
TMP_WITHOUT_CLOSES="$(mktemp)"
TMP_NONEXISTENT="/tmp/pr-body-closes-check-nonexistent-$$"
printf 'Closes #42\nSome body text\n' > "$TMP_WITH_CLOSES"
printf 'This is a PR without a closes reference\n' > "$TMP_WITHOUT_CLOSES"
rm -f "$TMP_NONEXISTENT"
# Add to the EXIT trap chain
trap 'rm -rf "$TMPDIR_BASE"; rm -f "$TMP_WITH_CLOSES" "$TMP_WITHOUT_CLOSES"' EXIT

# Allow paths (auto-close keyword present, or no body, or bypass)
run_case_warn "$HOOK" 'gh pr create --body "Closes #5"'              'gh pr create --body "Closes #5"'                  "allow"
run_case_warn "$HOOK" 'gh pr create --body "Fixes #5"'               'gh pr create --body "Fixes #5"'                   "allow"
run_case_warn "$HOOK" 'gh pr create --body "Resolves #5"'            'gh pr create --body "Resolves #5"'                "allow"
run_case_warn "$HOOK" 'gh pr create --body "Close #5"'               'gh pr create --body "Close #5"'                   "allow"
run_case_warn "$HOOK" 'gh pr create --body "Fix #5"'                 'gh pr create --body "Fix #5"'                     "allow"
run_case_warn "$HOOK" 'gh pr create --body "Resolve #5"'             'gh pr create --body "Resolve #5"'                 "allow"
run_case_warn "$HOOK" 'gh pr create --body "closes #5" (lowercase)'  'gh pr create --body "closes #5"'                  "allow"
run_case_warn "$HOOK" 'gh pr create --body "CLOSES #5" (uppercase)'  'gh pr create --body "CLOSES #5"'                  "allow"
run_case_warn "$HOOK" 'gh pr create --body multiline with Closes #5' 'gh pr create --body "## Summary\n- thing\n\nCloses #5"'  "allow"
run_case_warn "$HOOK" 'gh pr create (interactive, no body flag)'     'gh pr create'                                     "allow"
run_case_warn "$HOOK" 'gh pr create --draft (no body flag)'          'gh pr create --draft'                             "allow"
run_case_warn "$HOOK" 'gh pr create --body-file with Closes #N'      "gh pr create --body-file $TMP_WITH_CLOSES"        "allow"
run_case_warn "$HOOK" 'gh pr create --body-file nonexistent'         "gh pr create --body-file $TMP_NONEXISTENT"        "allow"
run_case_warn "$HOOK" 'compound: cd /tmp && gh pr create --body "Closes #5"' 'cd /tmp && gh pr create --body "Closes #5"' "allow"
CLAUDE_HOOK_BYPASS=1 run_case_warn "$HOOK" 'bypass via CLAUDE_HOOK_BYPASS=1' 'gh pr create --body "lorem ipsum"' "allow"
run_case_warn "$HOOK" 'git status (non-gh)'                          'git status'                                       "allow"

# Warn paths (missing auto-close keyword)
run_case_warn "$HOOK" 'gh pr create --body "lorem ipsum"'            'gh pr create --body "lorem ipsum"'                "warn"
run_case_warn "$HOOK" 'gh pr create --body "refs #5" (refs not auto-close)' 'gh pr create --body "refs #5"'             "warn"
run_case_warn "$HOOK" 'gh pr create --body-file without Closes #N'   "gh pr create --body-file $TMP_WITHOUT_CLOSES"     "warn"

# ===========================================================================
print_summary

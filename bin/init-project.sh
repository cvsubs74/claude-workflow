#!/usr/bin/env bash
# init-project.sh — replace {{PLACEHOLDERS}} in CLAUDE.md and agent files
# with project-specific values. Run once after cloning claude-workflow into a new repo.

set -euo pipefail

# Where we are
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo "==> claude-workflow project initializer"
echo "    Repo root: $REPO_ROOT"
echo

# Detect existing values
DEFAULT_BRANCH="$(git symbolic-ref --short HEAD 2>/dev/null || echo main)"
DEFAULT_REPO_NAME="$(basename "$REPO_ROOT")"

# Try to detect github remote
DEFAULT_GITHUB_REPO=""
if git remote get-url origin >/dev/null 2>&1; then
  REMOTE_URL="$(git remote get-url origin)"
  # Strip prefix/suffix to get owner/repo
  DEFAULT_GITHUB_REPO="$(echo "$REMOTE_URL" \
    | sed -E 's|^git@github.com:||; s|^https?://github.com/||; s|\.git$||')"
fi

# Prompt for each value
read -rp "Project name (human-readable) [$DEFAULT_REPO_NAME]: " PROJECT_NAME
PROJECT_NAME="${PROJECT_NAME:-$DEFAULT_REPO_NAME}"

read -rp "GitHub repo (owner/name) [$DEFAULT_GITHUB_REPO]: " GITHUB_REPO
GITHUB_REPO="${GITHUB_REPO:-$DEFAULT_GITHUB_REPO}"

read -rp "Default branch [$DEFAULT_BRANCH]: " DEFAULT_BRANCH_INPUT
DEFAULT_BRANCH="${DEFAULT_BRANCH_INPUT:-$DEFAULT_BRANCH}"

read -rp "Test command (or leave blank to fill in later): " TEST_COMMAND
read -rp "Lint command (or leave blank to fill in later): " LINT_COMMAND
read -rp "Dev server command (or leave blank to fill in later): " DEV_COMMAND
read -rp "Deploy command (or leave blank to fill in later): " DEPLOY_COMMAND

echo
echo "==> Will replace:"
echo "    {{PROJECT_NAME}}     -> $PROJECT_NAME"
echo "    {{GITHUB_REPO}}      -> $GITHUB_REPO"
echo "    {{DEFAULT_BRANCH}}   -> $DEFAULT_BRANCH"
echo "    {{TEST_COMMAND}}     -> ${TEST_COMMAND:-<blank>}"
echo "    {{LINT_COMMAND}}     -> ${LINT_COMMAND:-<blank>}"
echo "    {{DEV_COMMAND}}      -> ${DEV_COMMAND:-<blank>}"
echo "    {{DEPLOY_COMMAND}}   -> ${DEPLOY_COMMAND:-<blank>}"
echo
read -rp "Proceed? [y/N]: " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo "Aborted."
  exit 1
fi

# Files that may have placeholders
FILES=(
  "CLAUDE.md"
  ".claude/agents/team-lead-agent.md"
  ".claude/commands/onboard-team.md"
)

# sed -i differs between macOS and Linux
SED_INPLACE=(-i '')
if sed --version >/dev/null 2>&1; then
  # GNU sed
  SED_INPLACE=(-i)
fi

replace() {
  local placeholder="$1"
  local value="$2"
  # Skip if value is empty — leaves the placeholder in place so users see what's missing
  if [[ -z "$value" ]]; then
    return
  fi
  local esc
  esc="$(printf '%s' "$value" | sed -e 's/[\/&|]/\\&/g')"
  for f in "${FILES[@]}"; do
    if [[ -f "$f" ]]; then
      sed "${SED_INPLACE[@]}" -E "s|\{\{$placeholder\}\}|$esc|g" "$f"
    fi
  done
}

replace "PROJECT_NAME" "$PROJECT_NAME"
replace "GITHUB_REPO" "$GITHUB_REPO"
replace "DEFAULT_BRANCH" "$DEFAULT_BRANCH"
replace "TEST_COMMAND" "$TEST_COMMAND"
replace "LINT_COMMAND" "$LINT_COMMAND"
replace "DEV_COMMAND" "$DEV_COMMAND"
replace "DEPLOY_COMMAND" "$DEPLOY_COMMAND"

# Rename ARCHITECTURE.md.template if user wants
if [[ -f "docs/ARCHITECTURE.md.template" && ! -f "docs/ARCHITECTURE.md" ]]; then
  read -rp "Create docs/ARCHITECTURE.md from the template? [Y/n]: " CREATE_ARCH
  if [[ "$CREATE_ARCH" != "n" && "$CREATE_ARCH" != "N" ]]; then
    cp docs/ARCHITECTURE.md.template docs/ARCHITECTURE.md
    echo "    Created docs/ARCHITECTURE.md (template) — fill in for your project"
  fi
fi

# Seed settings.local.json from template
if [[ -f ".claude/settings.local.json.template" && ! -f ".claude/settings.local.json" ]]; then
  read -rp "Seed .claude/settings.local.json from the template? [Y/n]: " SEED_LOCAL
  if [[ "$SEED_LOCAL" != "n" && "$SEED_LOCAL" != "N" ]]; then
    cp .claude/settings.local.json.template .claude/settings.local.json
    echo "    Created .claude/settings.local.json (per-developer, gitignored)"
  fi
fi

# Offer to bootstrap labels via gh CLI (delegates to bin/bootstrap-labels.sh,
# which is also runnable standalone for recovery).
if command -v gh >/dev/null 2>&1 && [[ -n "$GITHUB_REPO" ]]; then
  echo
  read -rp "Bootstrap GitHub labels (bug, enhancement, backlog, prioritized, ...) on $GITHUB_REPO? [Y/n]: " BOOTSTRAP_LABELS
  if [[ "$BOOTSTRAP_LABELS" != "n" && "$BOOTSTRAP_LABELS" != "N" ]]; then
    "$SCRIPT_DIR/bootstrap-labels.sh" "$GITHUB_REPO"
  fi
fi

echo
echo "==> Done."
echo
echo "Next steps:"
echo "  1. Review CLAUDE.md — fill in 'Architecture in one paragraph' and any remaining commands"
echo "  2. Open Claude Code: claude"
echo "  3. Spawn the team: /onboard-team"

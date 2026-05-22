# Dev Agent Playbook

Project-specific notes that future-you (the Dev agent on this project) needs. Append a section when you learn something worth keeping; delete sections that go stale. Keep this readable end-to-end.

> **Promote-to-skill:** when a procedure here shows up in another agent's playbook too, or you've done it the same way 3+ times, lift it into a shared skill at `.claude/skills/<name>/SKILL.md`. See the `skill-maintenance` skill for the authoring pattern.

## Hook development gotchas

### Hook triggers block your own commands (including commits and PR creation)

The hooks run on every Bash tool call, including the tool calls used to test,
commit, and open PRs. If your commit message or PR body contains a phrase that
triggers a hook, the hook blocks the tool call itself.

**Workarounds:**
- Rephrase commit messages to avoid trigger tokens (e.g., describe "gh pr merge"
  as "the merge subcommand" rather than writing the literal phrase).
- Use `--body-file /tmp/body.md` for `gh pr create` when the PR body would
  contain trigger phrases (this is what code-reviewer-agent had to do in PR #26,
  and what motivated bug #28).
- Never use `CLAUDE_HOOK_BYPASS=1` to work around during normal dev — it disables
  ALL hooks. Only use for genuine ops emergencies.

### Writing hook regex: require command-position, not substring match

When a hook detects a command pattern, always require the pattern to appear at
the start of the command string OR after a shell separator (`; && || |`).
Scanning the full command string causes false positives when the pattern appears
inside a quoted argument (e.g., `grep "gh pr merge" SDLC.md` being blocked by
the merge hook).

Correct pattern (anchored to shell segment start):
```
(^|;|&&|\|\||[|])[[:space:]]*gh[[:space:]]+pr[[:space:]]+merge([[:space:]]|$)
```

Wrong (matches anywhere including inside quoted args):
```
\bgh[[:space:]]+pr[[:space:]]+merge\b
```

### Testing hooks locally without CLAUDE_HOOK_BYPASS

The test harness (`bash tests/run.sh`) pipes JSON payloads directly to hook
scripts, bypassing Claude Code's hook registration. Use this to verify hooks
work correctly. Do NOT try to pipe payloads interactively when those payloads
contain trigger phrases — Claude Code intercepts the tool call first.

### Hook tests that read real git state must use an env-var override

Hooks that call `git symbolic-ref --short HEAD` or similar at test time are
flaky: the result depends on which branch the test runner is checked out on.

Pattern: add an env-var override (e.g. `CLAUDE_HOOK_TEST_BRANCH`) that short-
circuits the git call. Set it in the test invocation; never rely on real git
state inside a test. Hook 1 uses this pattern; Hook 4 uses the analogous
`CLAUDE_HOOK_TEST_ROOT` for filesystem checks.

```bash
# Hermetic — branch is explicit, not read from git
CLAUDE_HOOK_TEST_BRANCH=feat/test run_case "$HOOK" "..." "git commit -m fix" "allow"
CLAUDE_HOOK_TEST_BRANCH=main      run_case "$HOOK" "..." "git commit -m fix" "block"
```

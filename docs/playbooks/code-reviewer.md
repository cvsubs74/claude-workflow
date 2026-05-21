# Code Reviewer Agent Playbook

Project-specific notes that future-you (the Code Reviewer agent on this project) needs. Append a section when you learn something worth keeping; delete sections that go stale. Keep this readable end-to-end.

> **Promote-to-skill:** when a procedure here shows up in another agent's playbook too, or you've done it the same way 3+ times, lift it into a shared skill at `.claude/skills/<name>/SKILL.md`. See the `skill-maintenance` skill for the authoring pattern.

## GitHub Actions — markdownlint-cli2-action config input

`DavidAnson/markdownlint-cli2-action` takes a **file path** in its `config:` input, not an inline JSON blob. Passing raw JSON causes the action to treat the JSON text as a filename and fail immediately with "File name should be (or end with) one of the supported types." The fix is to commit a `.markdownlint.json` (or `.markdownlint-cli2.jsonc`) file and pass its path, or to use `npx markdownlint-cli2` in a `run:` step and write the config inline there. Seen in PR #15.

## actions/checkout Node.js 20 deprecation

As of mid-2025 `actions/checkout@v4` emits Node.js 20 deprecation warnings on every run. The runner will force Node.js 24 in June 2026 and remove Node.js 20 in September 2026. Flag this as a non-blocking finding on any PR that uses `@v4`; recommend upgrading to `@v5`. Not a merge blocker today.

## Hook self-test harness — jq vs printf for JSON construction

When a bash self-test builds a JSON payload by interpolating a command string, `printf '{"command":"%s"}' "$cmd"` produces invalid JSON whenever `$cmd` contains literal double-quote characters. Use `jq -cn --arg cmd "$cmd" '{"tool_input":{"command":$cmd}}'` instead — jq properly escapes the quotes. The printf approach causes silent false-green tests (jq parse error → COMMAND="" → hook exits 0 → test reports "allow" when the hook would have blocked the real command). Seen in PR #17.

## Hook argument-list tokenizer — quote stripping for shell-quoted tokens

When a PreToolUse hook tokenizes push arguments with `for token in $PUSH_ARGS`, bash word-splits on IFS but does NOT strip shell quote characters. The token for `'origin'` is the five-character string `'origin'`, not `origin`. Strip matching outer single or double quote pairs from each token before comparison (`token="${token:1:${#token}-2}"` when the token matches `\'*\'` or `"*"`). Do not use `eval` — Option A (explicit strip) is safe and predictable. Seen in PR #17 Fix 2 / commit 81d300d.

## Hook edge cases that are non-blocking for no-direct-push-main.sh

These forms allow through and are acceptable — document rather than require fixes:
- Command substitution in the command string (`git push \`echo origin\` main`, `git push $(echo origin) main`): jq passes the literal text; backticks/dollar-parens are not shell-expanded in jq context. The remote token does not equal `origin`.
- Shell variables (`git push $REMOTE main`): same reasoning — literal `$REMOTE` does not equal `origin`.
- Unmatched quotes (`git push 'origin main`): malformed shell syntax; the shell rejects this at execution before the push runs. Consistent with fail-open design.
- Nested quotes (`git push "'origin'" "'main'"`): outer pair stripped → `'origin'` != `origin`, loop breaks. Non-exploitable; git would error on remote name `'origin'`.
- All of these require deliberate self-evasion; the escape hatch is `CLAUDE_HOOK_BYPASS=1`.

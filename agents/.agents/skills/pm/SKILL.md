---
name: pm
description: Use the `pm` shell command (alias for pm.ts) to check ploutos repo PR readiness, list unresolved review threads, and resolve review threads
---

# WCO (Ploutos PR Workflow)

Use this skill when the user asks about PR readiness or review-thread handling in the `ploutos` repo and wants to use `pm`. Prefer status/review/resolve; document and use start/close only when explicitly requested.

## Command Execution

- Run through interactive shell so alias/auth/env load: `zsh -ic 'pm <command> ...'`
- Prefer `-i` (interactive) rather than `-l` (login) to keep startup fast.
- If sandbox blocks network/home-shell access, rerun with escalated permissions.
- You have permission to run `zsh -ic 'pm <command> ...'` for commands status, review, and resolve

## Primary Agent Workflow (Most Common)

1. Check PR readiness:
   - `zsh -ic 'pm status'`
2. Pull unresolved review comments:
   - `zsh -ic 'pm review'`
3. Resolve only comments already fixed in code:
   - `zsh -ic 'pm resolve <thread-id>'`
4. Re-run review to confirm clean state:
   - `zsh -ic 'pm review'`

## Command Reference

- `pm start`
  - Creates ticket branch, empty commit, pushes branch, opens draft PR.
  - Prompts for Linear URL and commit message.
  - Must be run from `main`.

- `pm status`
  - Verifies current branch PR is ready.
  - Fails if draft, required checks not passing, or unresolved review threads exist.

- `pm close`
  - Squash-merges current branch PR, returns to `main`, prunes/deletes branch.
  - Must not be run from `main`; requires clean working tree.
  - Treat as destructive branch lifecycle action: run only with explicit user request.

- `pm review`
  - Lists unresolved PR review threads for the current branch PR.
  - Output includes `Thread ID: <id>` for each unresolved thread.
  - If no PR for branch, prints a no-PR message.

- `pm resolve <thread-id>`
  - Resolves one review thread by GitHub review thread ID from `pm review` output.

## Behavior Notes From Script

- Intended only for the `ploutos` repo.
- Requires `gh` auth to GitHub; no auth/network means commands fail.
- Backed by `~/dotfiles/scripts/pm.ts` (`zx` script).

## Safety Rules

- Resolve a thread only after code changes address that specific comment.
- Do not run `pm close` unless the user explicitly asks.
- After resolving threads, always verify with `pm review`.

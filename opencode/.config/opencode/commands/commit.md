---
description: Stage changes, generate a conventional commit, and commit
agent: committer
subtask: true
---

Create a git commit from the current working tree.

1. Review the current changes with `git status` and `git diff`.
2. Stage appropriate changes with `git add` (do NOT stage obvious secrets, junk, or unrelated artifacts)
3. Review the staged diff with `git diff --cached`.
4. Generate a concise Conventional Commit message based only on the staged changes.
5. Run `git commit` with that message.

Commit message rules:

* Use Conventional Commits format:
  `type(optional-scope): summary`
* Use a scope only when it adds useful context.
* Keep the summary short and clear.
* Use imperative present tense.
* Do not end the summary with a period.
* Optionally include a blank line followed by bullet points for meaningful details.
* Keep bullet points concise and reasonably short.
* Do not invent changes that are not present in the diff.

Use one of these types:

`feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `chore`, `ci`, `revert`

Do not ask for approval. Commit immediately.

Do not amend, reset, rebase, or push.

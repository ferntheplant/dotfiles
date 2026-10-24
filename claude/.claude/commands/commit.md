---
description: Stage changes, generate a conventional commit, and commit
argument-hint: [optional note about what to include]
context: fork
agent: committer
background: false
disable-model-invocation: true
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git add:*), Bash(git commit:*), Bash(git rev-parse:*), Bash(git log:*)
---

Create a git commit from the current working tree.

$ARGUMENTS

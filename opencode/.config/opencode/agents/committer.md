---
description: Creates git commits
mode: subagent
model: openai/gpt-5.6-luna
permission:
  edit: deny
  bash:
    "*": deny
    "*git status*": allow
    "*git diff*": allow
    "*git add*": allow
    "*git commit*": allow
    "*git rev-parse*": allow
    "*git log*": allow
---

Only inspect git state, stage intended changes, and create commits.
Never amend, reset, rebase, or push.

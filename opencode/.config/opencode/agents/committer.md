---
description: Creates git commits
mode: subagent
model: openai/gpt-5.6-luna
permissions:
  - action: edit
    resource: "*"
    effect: deny
  - action: shell
    resource: "*"
    effect: deny
  - action: shell
    resource: "*git status*"
    effect: allow
  - action: shell
    resource: "*git diff*"
    effect: allow
  - action: shell
    resource: "*git add*"
    effect: allow
  - action: shell
    resource: "*git commit*"
    effect: allow
  - action: shell
    resource: "*git rev-parse*"
    effect: allow
  - action: shell
    resource: "*git log*"
    effect: allow
---

Only inspect git state, stage intended changes, and create commits.
Never amend, reset, rebase, or push.

---
name: plan
description: Create, update, or refine implementation plans for engineering work. Use when the user wants to plan a task, break work into steps, investigate a system, audit code, or manage ongoing project progress. Triggered by requests like "create a plan for...", "break this into chunks", "plan the implementation of...", "audit the...", or explicitly via /plan. Supports two levels of detail — macro (high-level architecture and investigation) and micro (actionable TODOs with verification steps) — specified by the user or inferred from context.
---

# Plan

Plans live in `plans/<ticket-or-slug>/` and serve as a lightweight ticket/project management system. The plan file is the source of truth for what needs to happen, what's done, and what's blocked.

## Permissions

- You have permission to create, edit, and restructure files in the designated plan folder
- You do NOT have permission to modify application code — plans are documents only
- Ask the user follow-up clarification questions whenever an invariant, recovery path, or product decision is ambiguous

## Process

1. **Parse scope** — identify the flows, systems, or areas from the user's description
2. **Explore in parallel** — launch Explore agents (one per flow/area) to find all relevant files, trace data flows end-to-end, and identify error handling gaps, invariants, edge cases, race conditions, TODOs
3. **Read infrastructure** — after agent exploration, read shared files yourself (error types, utilities, context providers, layouts) to understand existing patterns
4. **Write the plan** — create/update the plan file at the path the user specifies (or `plans/<ticket-or-slug>/PLAN.md` by default)
5. **Ask follow-ups** — if decisions are needed before the plan can be finalized, ask the user rather than guessing

## Plan styles

The user will specify either **macro** or **micro**, or you can infer from context:

- **Macro** — high-level investigation and architecture. Use when scoping new work, auditing systems, or designing changes. See `references/macro.md` for layout details.
- **Micro** — actionable TODOs with verification steps, chunked into independently shippable units. Use when the user wants to execute on an existing plan or needs granular work items. See `references/micro.md` for layout details.

Both styles can coexist — the typical lifecycle is:

1. **Macro plan** written first (`PLAN.md`) — architecture, data models, flows, error handling
2. **Micro plans** generated from the macro plan — one file per chunk (`chunk-0.md`, `chunk-1.md`, ...) in the same plan folder
3. **Tracker** (`TRACKER.md`) created alongside micro plans to track completion

## Plan folder structure

```
plans/<ticket-or-slug>/
├── PLAN.md          # Macro plan — architecture and design
├── TRACKER.md       # Completion tracker — status of each chunk
├── chunk-0.md       # Micro plan for chunk 0
├── chunk-1.md       # Micro plan for chunk 1
└── ...
```

## Guidelines

- Be specific: file paths with line numbers, not vague descriptions
- Be opinionated: propose a concrete approach, don't just list problems
- Flag ambiguity: if the fix depends on a product decision, tag it `(Decision needed)`
- Group by user flow, not by file or technical layer
- Include cross-cutting concerns as a separate section
- Treat the plan as a living document — update it as work progresses, mark items done, add new items discovered during implementation

## Diagrams

Use mermaid diagrams in the **macro plan** to clarify architecture. Don't force them — only add them where a visual genuinely communicates better than text. Good candidates:

- **State machines** — `stateDiagram-v2` for status lifecycles
- **Workflow pipelines** — `flowchart TD` for multi-step processes with branching failure/recovery paths
- **Before/after comparisons** — paired `sequenceDiagram` blocks showing current vs proposed data flow
- **Decision trees** — `flowchart TD` for branching logic (e.g. error recovery, onComplete handlers)
- **Dependency graphs** — `flowchart LR` for chunk ordering

Avoid diagrams for things that are already clear from a table or short list. Micro plans rarely need diagrams — they are scoped for mechanical implementation where file paths and TODOs are more useful.

## Agent execution model

Micro plans are designed for **distinct agents to complete each chunk in sequence**. Each chunk must produce a commit that passes the project's verification command (lint, typecheck, tests). Keep this in mind:

- Each chunk's micro plan must be self-contained — an agent should be able to read just that chunk file and implement it without needing to understand the full macro plan
- Include the brief context sentence at the top of each chunk for the implementing agent
- Specify exact file paths, function names, and line ranges so the agent doesn't need to search
- The verification step at the end of each chunk should be a single command (e.g. `pnpm verify`)
- Cross-chunk runtime inconsistencies are acceptable when the whole plan ships as a single PR

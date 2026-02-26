# Micro Plan Reference

Micro plans break macro plans (or any large task) into actionable, trackable implementation chunks with explicit TODOs and verification steps. Each chunk is designed to be completed by a **separate agent** and must result in a **verified commit** (lint, typecheck, tests pass).

## Process

1. **Read the plan** — read the macro plan or task description
2. **Check completed work** — read git status and modified files to mark already-done items as ~~DONE~~
3. **Chunk the items** — group by natural breaking points (see Chunking Rules)
4. **Write the chunk files** — one file per chunk (`chunk-0.md`, `chunk-1.md`, ...) in the plan folder
5. **Create the tracker** — write `TRACKER.md` with completion table and dependency graph

## Output files

When creating micro plans, produce these files in the plan folder:

| File | Purpose |
|------|---------|
| `chunk-N.md` | One per chunk. Self-contained micro plan for an implementing agent. |
| `TRACKER.md` | Completion tracker with status table, dependency graph, and notes for agents. |

## Chunking Rules

- **Dependencies first**: infrastructure/cross-cutting goes in Chunk 0
- **Locality**: items touching the same files or flow belong together
- **Size**: 3-8 items per chunk (up to ~20 for large mechanical renames)
- **Independence**: each chunk should be independently testable
- **Commit-ready**: each chunk must pass the project's verification command when complete

## TODO Rules

- Each TODO is a single, concrete action — not "investigate and fix"
- If investigation is needed first, make it a separate TODO: `[ ] **TODO**: Read X and determine Y`
- If a user decision is needed, tag it: `[ ] **TODO**: (Decision needed) Choose between A and B`
- Mark optional/future items: `[ ] **TODO**: (Optional) ...` or `[ ] **TODO**: (Future) ...`

## Verification Rules

- Every item gets a **Verify** step
- Prefer automated verification (run test, call mutation, trigger error) over manual (read the code)
- Be specific: "confirm toast shows X" not "verify it works"
- **Every chunk ends with a final verification step** that runs the full verification command (e.g. `pnpm verify`). This is non-negotiable — it's what guarantees each chunk produces a valid commit.

## Chunk file template

```markdown
# Chunk N: <Name>

> Brief context sentence for the implementer. One or two sentences explaining what this chunk does
> and why, so an agent can orient without reading the full macro plan.

**Depends on**: Chunk X (brief reason)

## SN.1 — <Short description>

- **File**: `path/to/file.ts:line-range`
- **Problem**: One sentence.
- [ ] **TODO**: Specific action to take
- [ ] **TODO**: Another specific action
- **Verify**: How to confirm the fix works

## SN.2 — <Short description>

...

## SN.M — Final verification

- [ ] **TODO**: Run `pnpm verify` (or project-specific command) to confirm all lint, typecheck, and tests pass
- **Verify**: `pnpm verify` passes cleanly.
```

## Tracker file template

```markdown
# <Ticket> Tracker

## Verification Command

\`\`\`sh
pnpm verify   # or whatever the project uses
\`\`\`

Each chunk must pass this command before being marked complete.

## Chunk Completion

| Chunk | Name | Micro Plan | Status | Commit |
|-------|------|------------|--------|--------|
| 0 | <Name> | [chunk-0.md](./chunk-0.md) | `pending` | — |
| 1 | <Name> | [chunk-1.md](./chunk-1.md) | `pending` | — |
| ... | ... | ... | ... | ... |

## Dependencies

\`\`\`
Chunk 0  (description)
  └─► Chunk 1  (description)
        └─► Chunk 2  (description)
\`\`\`

## Notes for Agents

- Each chunk produces a commit that passes verification
- The entire plan ships as a single PR — cross-chunk runtime inconsistencies are acceptable
- (Add project-specific notes: generated files to not edit, migration order, etc.)
```

## Marking Conventions

- `[x]` — completed TODO (checked off by implementer or already done)
- `[ ]` — pending TODO
- `~~Strikethrough~~ DONE` — entire item completed
- `(Decision needed)` — requires user input before implementation
- `(Optional)` / `(Future)` — nice-to-have, not blocking

## Writing for agents

Each chunk file should be **self-contained enough for an agent to implement without reading the macro plan**. This means:

- The context sentence at the top orients the agent on *what* and *why*
- File paths include line numbers so the agent doesn't need to search
- Function names, variable names, and table names are spelled out exactly
- Dependencies on other chunks are stated explicitly ("Depends on: Chunk 1")
- The verification command is included — don't assume the agent knows the project's tooling

Diagrams are rarely useful in micro plans. The implementer needs file paths and TODOs, not architecture visuals. Only add a diagram if there's genuinely complex branching logic within a single chunk that would be confusing as text.

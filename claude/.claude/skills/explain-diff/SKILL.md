---
name: explain-diff
description: Rich, interactive Whiteboard explanation of a code change, diff, branch, or PR. Use when Fern asks to explain, walk through or visualize a diff, a branch, a commit or a PR.
---

# Explain Diff

Please make me a rich, interactive explanation of the specified code change, written as a Whiteboard review that I read in Whiteboard Desktop.

## Whiteboard

The Whiteboard MCP server provides the tools. If they are missing, ask me to run `whiteboard connect <agent>` and reload, and stop.

1. Call `session_get_instructions` (default topic) and read it. It is the reference for the authoring flow, the block types and the link format. Its section list is replaced by the sections below; follow everything else, including its first six steps.
2. Register the repository and create the review. For a PR, pass `pullRequestUrl` alone. If a review for that PR already exists, update it in place and follow its "updating existing whiteboard" steps.
3. Write each section below as a top-level `section`, in order, as soon as you have the material for it. I watch the canvas fill in, so write in small edits.
4. Read the whole review back with `session_get` (`full: true`). Fix contradictions, unverified claims and line numbers that point at the wrong code. Then end the lease with `session_activity_end`. Done when every section is written, the read-back is clean and the lease is ended.

## Sections

- Background: Explain the existing system relevant to this change. (You should broadly explore surrounding code for this.) We don't know how much the reader already knows, so put a deep background for beginners in a nested `section` with `defaultCollapsed: true`, and then a more narrow background directly relevant to the change.
- Intuition: Explain the core intuition for the code change. The focus here is to explain the essence, not the full details. Use concrete examples with toy data. Use figures and diagrams liberally.
- Code: Do a high-level walkthrough of the changes to the code. Group/order the changes in an understandable way, starting from the entry point a user or agent triggers. Use a `call_stack_diff` for each changed path, and a `code_peek` for the few spots that carry the mechanism or an invariant; link everything else inline.
- Quiz: Come up with five questions that test the reader's knowledge of this PR. This should be medium difficulty, difficult enough that you actually need to understand the substance of the PR to answer them, but not gotchas. The goal is to help the reader make sure that they've actually understood. Write each question as a nested `section` holding the question and lettered options, with a nested `section` titled "Answer" and `defaultCollapsed: true` that gives the correct option and feedback on each wrong one.

## Style

- Please write with the clarity and flow of Martin Kleppmann, making it engaging and written in classic style. Transitions between sections should be smooth.
- Some tips on diagrams. Ideally, you should pick a small number of diagram families that can be reused throughout the explanation to explain various cases:
  - `sequence` for components that talk to each other over time. Put example data in the step labels and explanations!
  - `flow_diagram` for branches, retries and state transitions.
  - `database_lens` for a schema change, or for who reads and writes a store.
  - For a UI change, a `flow_diagram` of the screens and what moves the user between them, or a simplified mock-up in a `code` block.
- Attach code to everything that describes code: a `source` on diagram steps and nodes, and `review-source:` links in prose.
- Use `callout` blocks for key concepts or definitions, important edge cases, etc.

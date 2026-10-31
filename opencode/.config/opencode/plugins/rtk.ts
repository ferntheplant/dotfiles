import { execFile } from "node:child_process"

// RTK OpenCode plugin — rewrites commands to use rtk for token savings.
// Requires: rtk >= 0.23.0 in PATH.
//
// This is a thin delegating plugin: all rewrite logic lives in `rtk rewrite`,
// which is the single source of truth (src/discover/registry.rs).
// To add or change rewrite rules, edit the Rust registry — not this file.
//
// The plugin exports the V2 definition object (`id` + `setup`) directly.
// It does not import `@opencode/plugin`: this file is symlinked from the
// dotfiles repository, so Bun resolves its real path, where that package is
// not installed. `Plugin.define` is only an identity helper.

// `rtk rewrite` exits non-zero when it rewrites the command, so ignore the exit
// code and read stdout directly. An empty result means "leave unchanged".
function rewriteCommand(command: string): Promise<string> {
  return new Promise((resolve) => {
    execFile("rtk", ["rewrite", command], (_error, stdout) => resolve(String(stdout ?? "")))
  })
}

function hasRtk(): Promise<boolean> {
  return new Promise((resolve) => {
    execFile("which", ["rtk"], (error) => resolve(!error))
  })
}

export default {
  id: "rtk",
  async setup(ctx) {
    if (!(await hasRtk())) {
      console.warn("[rtk] rtk binary not found in PATH — plugin disabled")
      return
    }

    await ctx.tool.hook("execute.before", async (event) => {
      const tool = event.tool.toLowerCase()
      if (tool !== "bash" && tool !== "shell") return
      if (!event.input || typeof event.input !== "object") return

      const input = event.input
      const command = input.command
      if (typeof command !== "string" || !command) return

      const rewritten = (await rewriteCommand(command)).trim()
      if (rewritten && rewritten !== command) {
        event.input = { ...input, command: rewritten }
      }
    })
  },
}

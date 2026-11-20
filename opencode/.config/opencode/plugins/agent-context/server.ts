// The server part of the agent-context plugin. It does three things:
//
//   - It gives the agent its identity, <model>+opencode@<host>, and the rule for its commit trailer.
//     See "Agent identity" in ~/dotfiles/README.md.
//   - It holds the first prompt of each new root session for a short time, until the entries from
//     tui.ts exist. Without the wait, the first model request can start before them.
//   - It removes the claude.ai account skills that Claude Code syncs into
//     ~/.claude/skills/synced/<account>/<skill>. Claude Code reads only the folders directly in
//     ~/.claude/skills, so it does not show them to the model. opencode searches six folders deep,
//     so it finds them. A policy cannot remove them, because it matches skill IDs, and the account
//     skills change. A permission hook cannot hide them, because the skill list does not use it.
//
// A background server serves every terminal, so its own environment belongs to the terminal that
// started it. Thus this part uses only the request, which holds the model, and never the server's
// environment. tui.ts adds the context that depends on the terminal.
import { Plugin } from "@opencode/plugin"
import type { Registration } from "@opencode/plugin/promise/registration"
import { execFileSync } from "node:child_process"
import { readFileSync } from "node:fs"
import { homedir } from "node:os"
import { join } from "node:path"

const dotfiles = join(homedir(), "dotfiles")
// The longest time that the first prompt of a session waits for the entries from tui.ts. A session
// from a terminal outside Rex gets no entries, so its first prompt waits this long.
const ENTRY_WAIT_MS = 250
const SYNCED_SKILLS = join(homedir(), ".claude/skills/synced") + "/"

function profile(): string {
  try {
    return readFileSync(join(dotfiles, ".work/profile"), "utf8").trim()
  } catch {
    return "desktop"
  }
}

// The Tailscale machine name, such as personal-macbook. scripts/opencode-settings.sh saves it, because
// tailnet-name.sh cannot always reach the Tailscale app, for example in a sandbox.
function host(): string {
  const saved = join(process.env.XDG_STATE_HOME || join(homedir(), ".local/state"), "dotfiles/tailnet-name")
  try {
    const name = readFileSync(saved, "utf8").trim()
    if (name) return name
  } catch {}
  try {
    return execFileSync(join(dotfiles, "scripts/tailnet-name.sh"), { encoding: "utf8", timeout: 5000 }).trim()
  } catch {
    return ""
  }
}

// claude-opus-5-5[1m] -> opus-5-5, the same form as the Claude Code identity
function modelName(id: string): string {
  return id.toLowerCase().replace(/.*\//, "").replace(/\[.*\]$/, "").replace(/^claude-/, "")
}

export default Plugin.define({
  id: "agent-context",
  setup(ctx) {
    // opencode adds the skills from ~/.claude/skills with a transform of its own, and the transforms
    // run in the order that they are registered. A transform that this plugin registers during setup
    // runs first, so it does not see those skills. Thus, when the skill list still has a synced skill,
    // register the transform again, so that it runs last, and load the skills again. The load sends
    // another skill.updated event, and then the list has no synced skill, so the loop ends.
    let removal: Registration | undefined
    const removeSyncedSkills = async () => {
      const { data } = await ctx.skill.list()
      if (!data.some((skill) => skill.path.startsWith(SYNCED_SKILLS))) return
      await removal?.dispose()
      removal = await ctx.skill.transform((editor) => {
        for (const skill of [...editor.list()]) {
          if (skill.path.startsWith(SYNCED_SKILLS)) editor.remove(skill.id)
        }
      })
      await ctx.skill.reload()
    }
    const updates = ctx.event.subscribe({ types: ["skill.updated"] })[Symbol.asyncIterator]()
    void (async () => {
      try {
        while (!(await updates.next()).done) await removeSyncedSkills().catch(() => {})
      } catch {}
    })()
    const first = setTimeout(() => removeSyncedSkills().catch(() => {}), 0)
    const cleanup = async () => {
      clearTimeout(first)
      await updates.return?.()
      await removal?.dispose()
    }

    const admitted = new Set<string>()
    ctx.session.hook("prompt", async (event) => {
      const sessionID = event.sessionID
      if (admitted.has(sessionID)) return
      admitted.add(sessionID)
      try {
        const session = await ctx.session.get({ sessionID })
        if (session.parentID) return
        const until = Date.now() + ENTRY_WAIT_MS
        while (Date.now() < until) {
          if ((await ctx.session.instructions.entry.list({ sessionID })).length > 0) return
          await new Promise((resolve) => setTimeout(resolve, 10))
        }
      } catch {}
    })

    // The work profile keeps each harness's own commit trailer.
    if (profile() === "work") return cleanup
    const machine = host()
    if (!machine) return cleanup

    ctx.session.hook("context", (event) => {
      const identity = `${modelName(event.model.id)}+opencode@${machine}`
      event.system.push({
        type: "text",
        text:
          `Your agent identity is ${identity}. End each git commit message with this trailer, ` +
          `in place of any other Co-Authored-By trailer for yourself:\n` +
          `Co-Authored-By: ${identity} <${identity}>`,
      })
    })
    return cleanup
  },
})

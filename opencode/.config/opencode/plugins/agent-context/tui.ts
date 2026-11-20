// Add the context that depends on the terminal to each session that this terminal shows:
//
//   - rex: Rex's own startup context (`rex __internal session-start`), in a Rex pane. Rex has no
//     startup hook for opencode, so this part does the work of the hook that Rex installs for
//     Claude Code. See "Rex support in opencode" in ~/dotfiles/README.md.
//   - agent-instructions: the text of the file in $AGENT_INSTRUCTIONS_FILE, when it is set. A
//     launcher uses it to add instructions, because opencode has no option for extra system text.
//
// It also records the session for Rex resume. See "Rex resume" in ~/dotfiles/README.md.
//
// This part runs in the terminal client, so process.env is the environment of this pane. The
// server serves every terminal and cannot tell the panes apart. Each entry is a durable instruction
// entry on the session. An entry that changes reaches the model at its next step.
import { Plugin } from "@opencode/plugin/tui"
import { execFileSync } from "node:child_process"
import { mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs"
import { homedir } from "node:os"
import { join } from "node:path"

function rexContext(): string {
  if (!process.env.REX_SESSION) return ""
  try {
    return execFileSync("rex", ["__internal", "session-start", "--agent", "opencode"], {
      encoding: "utf8",
      timeout: 5000,
      stdio: ["ignore", "pipe", "ignore"],
    }).trim()
  } catch {
    return ""
  }
}

function extraInstructions(): string {
  const file = process.env.AGENT_INSTRUCTIONS_FILE
  if (!file) return ""
  try {
    return readFileSync(file, "utf8").trim()
  } catch {
    return ""
  }
}

// One file for each pane: the session ID, the directory, an empty transcript field, and the agent.
// ~/.zsh/rex-resume.zsh reads it when Rex restores the pane.
function recordForResume(block: string, sessionID: string) {
  try {
    const dir = join(process.env.XDG_STATE_HOME || join(homedir(), ".local/state"), "rex-resume")
    mkdirSync(dir, { recursive: true })
    const tmp = join(dir, `.tmp.${process.pid}`)
    writeFileSync(tmp, `${sessionID}\t${process.cwd()}\t\topencode\n`)
    renameSync(tmp, join(dir, block))
  } catch {}
}

export default Plugin.define({
  id: "agent-context",
  setup(ctx) {
    const block = process.env.REX_BLOCK
    const entries: Record<string, string> = {}
    const rex = rexContext()
    if (rex) entries["rex"] = rex
    const extra = extraInstructions()
    if (extra) entries["agent-instructions"] = extra
    if (!block && Object.keys(entries).length === 0) return

    let shown: string | undefined
    const sync = () => {
      const route = ctx.ui.router.current()
      if (route.type !== "session" || route.sessionID === shown) return
      const sessionID = route.sessionID
      shown = sessionID
      // A subagent's session belongs to its parent. Only the parent names the Rex session.
      if (ctx.data.session.root(sessionID) !== sessionID) return
      for (const [key, value] of Object.entries(entries)) {
        ctx.client.experimental.session.instructions.entry.put({ sessionID, key, value }).catch(() => {})
      }
      if (block) recordForResume(block, sessionID)
    }
    sync()
    return ctx.data.listen(sync)
  },
})

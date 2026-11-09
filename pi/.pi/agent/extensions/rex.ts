import { execFileSync } from "node:child_process"
import { homedir } from "node:os"
import { join } from "node:path"

// Rex's session-start hook for Pi. `rex skill setup` gives Claude Code and Codex a SessionStart hook
// that tells the agent its Rex session and pane, and asks it to name the session after its task.
// Pi has no command hooks, so Rex installs only its skill for Pi. This extension runs the same
// command, `rex __internal session-start --agent pi`, and adds its output to the system prompt.
// The text comes from the installed Rex, so it changes when Rex updates.
//
// It does nothing outside a Rex terminal (no REX_SESSION), in a subagent (PI_SUBAGENT=1, from
// subagent.ts: a child must not rename the session), or when the rex command fails.
//
// It imports no Pi package: this file is linked from ~/dotfiles, where no Pi package is installed.

const REX_APP_CLI = join(
  homedir(),
  "Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS/rex",
)

function sessionStartText(): string | undefined {
  for (const rex of ["rex", REX_APP_CLI]) {
    try {
      const text = execFileSync(rex, ["__internal", "session-start", "--agent", "pi"], {
        encoding: "utf8",
        stdio: ["ignore", "pipe", "ignore"],
        timeout: 5000,
      }).trim()
      return text || undefined
    } catch (error: any) {
      // Try the next path only when this one is not there; any other failure means no Rex text
      if (error?.code !== "ENOENT") return undefined
    }
  }
  return undefined
}

export default function (pi: any) {
  if (!process.env.REX_SESSION || process.env.PI_SUBAGENT === "1") return

  let text: string | undefined
  pi.on("session_start", () => {
    text = sessionStartText()
  })
  pi.on("before_agent_start", (event: any) => {
    if (!text) return
    return { systemPrompt: `${event.systemPrompt}\n\n<rex>\n${text}\n</rex>` }
  })
}

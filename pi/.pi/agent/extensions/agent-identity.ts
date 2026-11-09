import { hostname } from "node:os"

// Pi's agent identity, <model>+pi@<host>, for example kimi-k3+pi@lil-homie (see "Agent identity" in
// ~/dotfiles/README.md). It follows the model: a /model switch changes it.
//
// - Kata: it sets KATA_AUTHOR on the Pi process, so the bash tool and Kata's own extension
//   (extensions/kata.js, from `kata agent-hook install pi`) both get it.
// - Commits: it tells Pi to end each commit message with a Co-Authored-By trailer for the identity.
//
// It imports no Pi package: this file is linked from ~/dotfiles, where no Pi package is installed.

const host = hostname().split(".")[0]

// moonshotai/Kimi-K3 -> kimi-k3, claude-opus-5-5 -> opus-5-5
function identity(modelId: string): string {
  const model = modelId.toLowerCase().replace(/.*\//, "").replace(/\[.*\]$/, "").replace(/^claude-/, "")
  return `${model}+pi@${host}`
}

function setModel(model?: { id?: string }) {
  if (model?.id) process.env.KATA_AUTHOR = identity(model.id)
}

export default function (pi: any) {
  pi.on("session_start", (_event: any, ctx: any) => setModel(ctx.model))
  pi.on("model_select", (event: any) => setModel(event.model))
  pi.on("before_agent_start", (event: any) => {
    const id = process.env.KATA_AUTHOR
    if (!id?.includes("+pi@")) return
    return {
      systemPrompt: `${event.systemPrompt}\n\nYour agent identity is ${id}. It is your Kata actor (KATA_AUTHOR). End each git commit message with this trailer:\nCo-Authored-By: ${id} <${id}>`,
    }
  })
}

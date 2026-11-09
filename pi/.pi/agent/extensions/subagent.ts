import { spawn } from "node:child_process"
import { existsSync } from "node:fs"
import { basename } from "node:path"

// A minimal `subagent` tool. Each task runs in a new child Pi process (`pi -p --mode json`) with the
// parent's model and thinking level, and the tool returns each child's final answer. Tasks in one
// call run in parallel. There are no agent types, chains, or background runs.
//
// A child gets the same settings, extensions, skills, and instructions as the parent, but none of the
// parent's conversation. A child does not get this tool: PI_SUBAGENT=1 stops it from registering, so
// a subagent cannot start more subagents.
//
// It imports no Pi package: this file is linked from ~/dotfiles, where no Pi package is installed.

const MAX_TASKS = 8
const MAX_CONCURRENT = 4
const MAX_OUTPUT_CHARS = 40_000
const STDERR_TAIL_CHARS = 2_000

type Result = { task: string; output: string; ok: boolean; turns: number; usage: any }

// Pi is either a script run by node/bun, or one compiled binary (the mise install is one)
function piCommand(args: string[]): { command: string; args: string[] } {
  const script = process.argv[1]
  if (script && !script.startsWith("/$bunfs/") && existsSync(script)) {
    return { command: process.execPath, args: [script, ...args] }
  }
  if (!/^(node|bun)(\.exe)?$/i.test(basename(process.execPath))) return { command: process.execPath, args }
  return { command: "pi", args }
}

// Add each number in `add` to the same field in `total` (Pi's Usage, including its cost object)
function addUsage(total: any, add: any): any {
  if (!add || typeof add !== "object") return total
  const out = { ...total }
  for (const [key, value] of Object.entries(add)) {
    if (typeof value === "number") out[key] = (typeof out[key] === "number" ? out[key] : 0) + value
    else if (value && typeof value === "object") out[key] = addUsage(out[key] ?? {}, value)
  }
  return out
}

function assistantText(message: any): string {
  if (!Array.isArray(message?.content)) return typeof message?.content === "string" ? message.content : ""
  return message.content
    .filter((part: any) => part?.type === "text")
    .map((part: any) => part.text)
    .join("")
}

function runChild(
  task: string,
  cwd: string,
  model: string | undefined,
  thinking: string | undefined,
  signal: AbortSignal | undefined,
  onProgress: (turns: number) => void,
): Promise<Result> {
  const args = ["--mode", "json", "-p", "--no-session"]
  if (model) args.push("--model", model)
  if (thinking) args.push("--thinking", thinking)
  args.push(task)

  return new Promise((resolve) => {
    const { command, args: argv } = piCommand(args)
    const child = spawn(command, argv, {
      cwd,
      env: { ...process.env, PI_SUBAGENT: "1" },
      stdio: ["ignore", "pipe", "pipe"],
    })
    let buffer = ""
    let stderr = ""
    let finalText = ""
    let error = ""
    let turns = 0
    let usage: any = {}
    let aborted = false

    const onLine = (line: string) => {
      let event: any
      try {
        event = JSON.parse(line)
      } catch {
        return
      }
      if (event.type !== "message_end" || event.message?.role !== "assistant") return
      turns++
      usage = addUsage(usage, event.message.usage)
      onProgress(turns)
      const text = assistantText(event.message)
      if (text.trim()) finalText = text
      if (event.message.errorMessage) error = event.message.errorMessage
    }

    child.stdout.on("data", (data) => {
      buffer += data.toString()
      const lines = buffer.split("\n")
      buffer = lines.pop() ?? ""
      for (const line of lines) if (line.trim()) onLine(line)
    })
    child.stderr.on("data", (data) => {
      stderr = (stderr + data.toString()).slice(-STDERR_TAIL_CHARS)
    })

    const kill = () => {
      aborted = true
      child.kill("SIGTERM")
      setTimeout(() => child.exitCode === null && child.kill("SIGKILL"), 5000).unref()
    }
    if (signal?.aborted) kill()
    else signal?.addEventListener("abort", kill, { once: true })

    const finish = (code: number | null) => {
      signal?.removeEventListener("abort", kill)
      if (buffer.trim()) onLine(buffer)
      const ok = code === 0 && !error && !aborted && finalText.trim() !== ""
      let output = finalText
      if (aborted) output = "Stopped: the subagent was aborted."
      else if (!ok) {
        const reason = error || stderr.trim() || `pi exited with code ${code}`
        output = `${finalText ? `${finalText}\n\n` : ""}Subagent failed: ${reason}`
      }
      if (output.length > MAX_OUTPUT_CHARS) output = `${output.slice(0, MAX_OUTPUT_CHARS)}\n\n[output truncated]`
      resolve({ task, output, ok, turns, usage })
    }
    child.on("close", finish)
    child.on("error", (err) => {
      stderr += String(err)
      finish(1)
    })
  })
}

// Run fn on each item, with at most `limit` running at once, and keep the input order
async function mapLimited<T, R>(items: T[], limit: number, fn: (item: T, index: number) => Promise<R>) {
  const results: R[] = new Array(items.length)
  let next = 0
  const worker = async () => {
    while (next < items.length) {
      const index = next++
      results[index] = await fn(items[index], index)
    }
  }
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, worker))
  return results
}

export default function (pi: any) {
  if (process.env.PI_SUBAGENT === "1") return

  pi.registerTool({
    name: "subagent",
    label: "Subagent",
    description: [
      "Run tasks in new child agents, each with its own empty context window.",
      "A child has your model, tools, skills, and instructions, but it does not see this conversation:",
      "write each task so that it has all the context and file paths the child needs, and say what to return.",
      `Tasks in one call run in parallel (at most ${MAX_TASKS}). The result is each child's final answer.`,
      "Use it for independent work, or to keep long searches and reading out of your own context.",
    ].join(" "),
    parameters: {
      type: "object",
      properties: {
        tasks: {
          type: "array",
          items: { type: "string" },
          minItems: 1,
          maxItems: MAX_TASKS,
          description: "One complete, self-contained task for each child agent.",
        },
        cwd: { type: "string", description: "Working directory for the children. Defaults to your own." },
      },
      required: ["tasks"],
      additionalProperties: false,
    },

    async execute(_id: string, params: any, signal: AbortSignal | undefined, onUpdate: any, ctx: any) {
      const tasks: string[] = (params.tasks ?? []).filter((t: unknown) => typeof t === "string" && t.trim())
      if (tasks.length === 0 || tasks.length > MAX_TASKS) {
        return {
          content: [{ type: "text", text: `Give 1 to ${MAX_TASKS} non-empty tasks.` }],
          details: {},
          isError: true,
        }
      }
      const model = ctx.model ? `${ctx.model.provider}/${ctx.model.id}` : undefined
      const thinking = pi.getThinkingLevel?.() ?? ctx.thinkingLevel
      const cwd = params.cwd || ctx.cwd
      if (!existsSync(cwd)) {
        return { content: [{ type: "text", text: `The directory ${cwd} does not exist.` }], details: {}, isError: true }
      }

      const turns = tasks.map(() => 0)
      const done = tasks.map(() => false)
      const progress = () =>
        onUpdate?.({
          content: [
            {
              type: "text",
              text: tasks
                .map((_, i) => `${i + 1}. ${done[i] ? "done" : "running"} (${turns[i]} turns)`)
                .join("\n"),
            },
          ],
          details: {},
        })
      progress()

      const results = await mapLimited(tasks, MAX_CONCURRENT, async (task, i) => {
        const result = await runChild(task, cwd, model, thinking, signal, (n) => {
          turns[i] = n
          progress()
        })
        done[i] = true
        progress()
        return result
      })

      const text =
        results.length === 1
          ? results[0].output
          : results.map((r, i) => `## Subagent ${i + 1}${r.ok ? "" : " (failed)"}\n\n${r.output}`).join("\n\n")
      const usage = results.reduce((total, r) => addUsage(total, r.usage), {})
      return { content: [{ type: "text", text }], details: {}, usage, isError: results.every((r) => !r.ok) }
    },
  })
}

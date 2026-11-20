// The TUI part of the status-footer plugin. It adds two things:
//
//   - In the footer row, after opencode's own cwd:branch: the context that remains, and the
//     five-hour and weekly quota that remains for the provider of the selected model, with the time
//     to each reset. Example: `62% ctx left · 5h 71% (2h10m)  7d 38% (3d4h)`.
//   - In the row above the input: `stopped at HH:MM`, the time that the last turn ended. Use it to
//     tell whether the provider prompt cache has likely expired.
//
// Quota marks: `?` means unknown, `~` marks a value older than 10 minutes, and a passed reset shows
// `? (now)` until a newer value arrives. openai and claude-agent quota come from the server part.
// OpenCode Go quota comes from opencode's usage-limits call, which needs an OpenCode Console sign-in.
// See "opencode plugins" in ~/dotfiles/README.md.
//
// Written without JSX, so opencode loads the file as it is, with no build step.
import { Plugin } from "@opencode/plugin/tui"
import type { RGBA } from "@opentui/core"
import { createElement, insert, setProp } from "@opentui/solid"
import { createSignal, type JSX } from "solid-js"
import { QuotaRpc, type QuotaReport, type QuotaSnapshot, type QuotaWindow } from "./rpc.ts"

const MINUTE = 60_000
const STALE_MS = 10 * MINUTE
const TICK_MS = 15_000
const GO_REFRESH_MS = MINUTE

type Run = { text: string; color?: RGBA }

function node(tag: string, props: Record<string, unknown>, children: unknown[] = []): JSX.Element {
  const element = createElement(tag)
  for (const [key, value] of Object.entries(props)) setProp(element, key, value)
  for (const child of children) insert(element, child as JSX.Element)
  return element as unknown as JSX.Element
}

function line(runs: () => Run[]): JSX.Element {
  return node("text", { wrapMode: "none", flexShrink: 0 }, [
    () => runs().map((run) => node("span", { style: { fg: run.color } }, [run.text])),
  ])
}

function countdown(reset: number | undefined, now: number): string {
  if (reset === undefined || !Number.isFinite(reset)) return "?"
  if (reset <= now) return "now"
  const minutes = Math.ceil((reset - now) / MINUTE)
  if (minutes < 60) return `${minutes}m`
  const hours = Math.floor(minutes / 60)
  if (hours < 24) return `${hours}h${minutes % 60 ? `${minutes % 60}m` : ""}`
  return `${Math.floor(hours / 24)}d${hours % 24 ? `${hours % 24}h` : ""}`
}

function stamp(at: number, now: number): string {
  const time = new Date(at)
  const pad = (n: number) => String(n).padStart(2, "0")
  const clock = `${pad(time.getHours())}:${pad(time.getMinutes())}`
  if (time.toDateString() === new Date(now).toDateString()) return clock
  return `${time.getFullYear()}-${pad(time.getMonth() + 1)}-${pad(time.getDate())} ${clock}`
}

export default Plugin.define({
  id: "status-footer",
  setup(ctx) {
    const theme = () => ctx.theme
    const [now, setNow] = createSignal(Date.now())
    const [report, setReport] = createSignal<QuotaReport>({})
    const [go, setGo] = createSignal<QuotaSnapshot | null>(null)
    let goFetched = 0

    const provider = () => ctx.ui.model.current()?.providerID

    const refresh = async () => {
      setNow(Date.now())
      try {
        setReport((await ctx.client.rpc(QuotaRpc).read({})) as QuotaReport)
      } catch {}
      if (provider() === "opencode-go" && Date.now() - goFetched >= GO_REFRESH_MS) {
        goFetched = Date.now()
        try {
          const meters = (await ctx.client.experimental.usage.limits()).data?.go
          if (meters) {
            const window = (m: { percent: number; resetsAt: number }): QuotaWindow => ({
              usedPercent: m.percent,
              resetsAt: m.resetsAt,
            })
            setGo({ five: window(meters.rolling), week: window(meters.weekly), at: Date.now() })
          }
        } catch {}
      }
    }

    // Context left: the tokens of the last reply with usage, against the selected model's window.
    const contextLeft = (sessionID: string | undefined): number | undefined => {
      if (!sessionID) return undefined
      const messages = ctx.data.session.message.list(sessionID)
      let used = 0
      for (let i = messages.length - 1; i >= 0; i--) {
        const message = messages[i]
        if (message.type !== "assistant" || !message.tokens) continue
        const t = message.tokens
        used = t.input + t.output + t.reasoning + t.cache.read + t.cache.write
        if (used > 0) break
      }
      if (used <= 0) return undefined
      const current = ctx.ui.model.current()
      const model = ctx.data.location.model
        .list()
        ?.find((m) => m.providerID === current?.providerID && (m.modelID === current?.modelID || m.id === current?.modelID))
      const window = model?.limit.context
      if (!window) return undefined
      return Math.max(0, Math.min(100, Math.round(100 - (used / window) * 100)))
    }

    const quotaRuns = (label: string, snapshot: QuotaSnapshot | null | undefined, window: QuotaWindow | undefined, at: number): Run[] => {
      const t = theme()
      if (!snapshot || !window) return [{ text: `${label} `, color: t.text.muted }, { text: "?", color: t.text.feedback.warning.base }]
      const expired = window.resetsAt !== undefined && window.resetsAt <= at
      const stale = at - snapshot.at > STALE_MS
      const left = Math.max(0, Math.min(100, Math.round(100 - window.usedPercent)))
      const color =
        expired || stale || left <= 20 ? t.text.feedback.warning.base : left <= 50 ? t.text.feedback.info.base : t.text.feedback.success.base
      return [
        { text: `${label} `, color: t.text.muted },
        { text: expired ? "?" : `${stale ? "~" : ""}${left}%`, color },
        { text: ` (${countdown(window.resetsAt, at)})`, color: t.text.faint },
      ]
    }

    const footerRuns = (sessionID: string | undefined): Run[] => {
      const t = theme()
      const at = now()
      const left = contextLeft(sessionID)
      const runs: Run[] = [
        { text: " · ", color: t.text.faint },
        { text: `${left ?? "?"}% ctx left`, color: left !== undefined && left <= 20 ? t.text.feedback.warning.base : t.text.muted },
      ]
      const id = provider()
      const snapshot = id === "opencode-go" ? go() : id ? report()[id] : undefined
      if (id === "opencode-go" || (id && id in report())) {
        runs.push({ text: " · ", color: t.text.faint })
        runs.push(...quotaRuns("5h", snapshot, snapshot?.five, at))
        runs.push({ text: "  " })
        runs.push(...quotaRuns("7d", snapshot, snapshot?.week, at))
      }
      return runs
    }

    // The last reply that ended a turn: it did not stop to call a tool, or it failed.
    const stopTime = (sessionID: string): number | undefined => {
      if (ctx.data.session.status(sessionID) === "running") return undefined
      const messages = ctx.data.session.message.list(sessionID)
      for (let i = messages.length - 1; i >= 0; i--) {
        const message = messages[i]
        if (message.type !== "assistant") continue
        const ended = message.error || (message.finish && message.finish !== "tool-calls" && message.finish !== "unknown")
        return ended ? message.time.completed : undefined
      }
      return undefined
    }

    const releaseFooter = ctx.ui.slot({
      append: "prompt.footer.status",
      render: (input) => line(() => footerRuns(input.sessionID)),
    })
    const releaseStop = ctx.ui.slot({
      append: "session.composer.top",
      render: (input) =>
        line(() => {
          const at = stopTime(input.sessionID)
          return at === undefined ? [] : [{ text: `stopped at ${stamp(at, now())}`, color: theme().text.faint }]
        }),
    })

    const offEvents = ctx.data.listen(({ details }) => {
      if (details.type === "session.step.ended" || details.type.startsWith("session.execution.")) void refresh()
    })
    const timer = setInterval(() => void refresh(), TICK_MS)
    void refresh()

    return () => {
      clearInterval(timer)
      offEvents()
      releaseFooter()
      releaseStop()
    }
  },
})

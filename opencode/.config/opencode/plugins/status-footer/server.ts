// The server part of the status-footer plugin. It keeps the five-hour and weekly quota that the
// providers report on normal model responses. It sends no request and reads no credential.
//
//   - openai (a ChatGPT sign-in): the Codex backend sends `codex.rate_limits` WebSocket frames and
//     `x-codex-primary-*` / `x-codex-secondary-*` response headers.
//   - claude-agent: opencode keeps the Claude Agent SDK's `rate_limit_event` on each step, in
//     `native.rateLimit`. Its `unifiedWindows` holds the five-hour and the seven-day window.
//
// OpenCode Go needs no server part: the TUI part reads it with opencode's own usage-limits call.
// See "opencode plugins" in ~/dotfiles/README.md.
import { Plugin } from "@opencode/plugin"
import type { Registration } from "@opencode/plugin/promise/registration"
import { QuotaRpc, type QuotaReport, type QuotaSnapshot, type QuotaWindow } from "./rpc.ts"

const PROVIDERS = ["openai", "claude-agent"] as const
type Slot = "five" | "week"

// Seconds or milliseconds since the epoch, to milliseconds
function epochMs(value: unknown): number | undefined {
  const n = typeof value === "string" ? Number(value) : value
  if (typeof n !== "number" || !Number.isFinite(n) || n <= 0) return undefined
  return n < 1e12 ? n * 1000 : n
}

function percent(value: unknown): number | undefined {
  const n = typeof value === "string" ? Number(value) : value
  return typeof n === "number" && Number.isFinite(n) ? Math.max(0, Math.min(100, n)) : undefined
}

// A Codex window goes by its length, and by its position when the length is unknown.
function codexSlot(minutes: unknown, position: Slot): Slot | undefined {
  const n = Number(minutes)
  if (n === 300) return "five"
  if (n === 10080) return "week"
  return Number.isFinite(n) && n > 0 ? undefined : position
}

export default Plugin.define({
  id: "status-footer",
  async setup(ctx) {
    // Plugin storage is shared by the plugin in every project, and it survives a server restart.
    const save = async (provider: (typeof PROVIDERS)[number], windows: Partial<Record<Slot, QuotaWindow>>) => {
      if (!windows.five && !windows.week) return
      const previous = (await ctx.storage.get(`quota/${provider}`)) as QuotaSnapshot | undefined
      const next: QuotaSnapshot = { ...previous, ...windows, at: Date.now() }
      await ctx.storage.set(`quota/${provider}`, next)
    }

    const codexWindow = (window: unknown, position: Slot, into: Partial<Record<Slot, QuotaWindow>>) => {
      if (!window || typeof window !== "object") return
      const w = window as Record<string, unknown>
      const used = percent(w.used_percent)
      const slot = codexSlot(w.window_minutes, position)
      if (used === undefined || !slot) return
      into[slot] = { usedPercent: used, resetsAt: epochMs(w.reset_at ?? w.resets_at) }
    }

    const registrations: Registration[] = []

    registrations.push(
      await ctx.session.hook(
        "experimental.ws.receive",
        async (event) => {
          // This hook runs on every frame, so test the text before the parse.
          if (!event.frame.includes("codex.rate_limits")) return
          let body: any
          try {
            body = JSON.parse(event.frame)
          } catch {
            return
          }
          if (body?.type !== "codex.rate_limits" || !body.rate_limits) return
          const windows: Partial<Record<Slot, QuotaWindow>> = {}
          codexWindow(body.rate_limits.primary, "five", windows)
          codexWindow(body.rate_limits.secondary, "week", windows)
          await save("openai", windows)
        },
        { providerID: "openai" },
      ),
    )

    registrations.push(
      await ctx.session.hook(
        "http.response",
        async (event) => {
          // Read the response headers only. The request holds the credential.
          const headers = event.response.headers
          const windows: Partial<Record<Slot, QuotaWindow>> = {}
          for (const [name, position] of [["primary", "five"], ["secondary", "week"]] as const) {
            codexWindow(
              {
                used_percent: headers.get(`x-codex-${name}-used-percent`) ?? undefined,
                window_minutes: headers.get(`x-codex-${name}-window-minutes`) ?? undefined,
                reset_at: headers.get(`x-codex-${name}-reset-at`) ?? undefined,
              },
              position,
              windows,
            )
          }
          await save("openai", windows)
        },
        { providerID: "openai" },
      ),
    )

    // claude-agent: each step that ends carries the newest rate-limit event of its request.
    const steps = ctx.event.subscribe({ types: ["session.step.ended"] })[Symbol.asyncIterator]()
    void (async () => {
      try {
        while (true) {
          const next = await steps.next()
          if (next.done) break
          const limit = (next.value.data.native as any)?.rateLimit
          if (!limit || typeof limit !== "object") continue
          const windows: Partial<Record<Slot, QuotaWindow>> = {}
          const add = (slot: Slot, value: any) => {
            const utilization = Number(value?.utilization)
            if (!Number.isFinite(utilization)) return
            // The CLI reports utilization as a fraction, such as 0.12 for 12%.
            windows[slot] = {
              usedPercent: percent(utilization <= 1 ? utilization * 100 : utilization)!,
              resetsAt: epochMs(value?.resetsAt),
            }
          }
          if (limit.unifiedWindows) {
            add("five", limit.unifiedWindows.five_hour)
            add("week", limit.unifiedWindows.seven_day)
          } else if (limit.rateLimitType === "five_hour") add("five", limit)
          else if (limit.rateLimitType === "seven_day") add("week", limit)
          await save("claude-agent", windows).catch(() => {})
        }
      } catch {}
    })()

    registrations.push(
      await ctx.rpc.register(QuotaRpc, {
        read: async () => {
          const report: QuotaReport = {}
          for (const provider of PROVIDERS) {
            report[provider] = ((await ctx.storage.get(`quota/${provider}`)) as QuotaSnapshot | undefined) ?? null
          }
          return report
        },
      }),
    )

    return async () => {
      await steps.return?.()
      for (const registration of registrations) await registration.dispose()
    }
  },
})

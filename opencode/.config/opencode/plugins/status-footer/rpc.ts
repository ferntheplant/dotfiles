// The contract between the server part and the TUI part of the status-footer plugin. The server part
// keeps the quota that it sees on model responses, and the TUI part reads it with `read`.
import { Rpc } from "@opencode/plugin/rpc"

/** One quota window. `usedPercent` is 0 to 100. `resetsAt` is in milliseconds since the epoch. */
export type QuotaWindow = { usedPercent: number; resetsAt?: number }
/** The newest value of each window of one provider. `at` is when the server part saw the newest value. */
export type QuotaSnapshot = { five?: QuotaWindow; week?: QuotaWindow; at: number }
export type QuotaReport = Record<string, QuotaSnapshot | null>

export const QuotaRpc = Rpc.define({
  id: "status-footer",
  methods: {
    read: {
      input: { type: "object", properties: {}, additionalProperties: false },
      output: { type: "object" },
    },
  },
  events: {},
})

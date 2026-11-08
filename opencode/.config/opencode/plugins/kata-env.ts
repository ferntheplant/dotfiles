import { hostname } from "node:os"

// Kata actor for OpenCode: each issue, comment, and close that OpenCode makes is attributed to
// opencode@<host>, for example opencode@lil-homie. A KATA_AUTHOR from the launching shell wins.
//
// It sets the variable on the OpenCode process when the plugin loads, so the Kata plugin's own
// kata calls (plugins/kata-user, from `kata agent-hook install opencode`) and the shell tool both
// get it. The daemon target comes from ~/.kata/config.toml (the kata stow package).
//
// Like rtk.ts, this exports the V2 definition object directly and imports no plugin package.

process.env.KATA_AUTHOR ||= `opencode@${hostname().split(".")[0]}`

export default {
  id: "kata-env",
  async setup() {},
}

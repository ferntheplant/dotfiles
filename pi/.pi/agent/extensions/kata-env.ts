import { hostname } from "node:os"

// Kata actor for Pi: each issue, comment, and close that Pi makes is attributed to pi@<host>, for
// example pi@lil-homie. A KATA_AUTHOR from the launching shell wins.
//
// It sets the variable on the Pi process when the extension loads, so the bash tool and Kata's own
// extension (extensions/kata.js, from `kata agent-hook install pi`) both get it. The daemon target
// comes from ~/.kata/config.toml (the kata stow package).
//
// It imports no Pi package: this file is linked from ~/dotfiles, where no Pi package is installed.

process.env.KATA_AUTHOR ||= `pi@${hostname().split(".")[0]}`

export default function () {}

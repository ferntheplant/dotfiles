// Ghostty theme file — https://ghostty.org/docs/features/theme
//
// Mirrors the theme's VS Code integrated terminal (terminal.ansi*, terminal.background/
// foreground) so shells look the same as in VS Code. Selection is the editor selection color,
// flattened, and splits use the muted color because theme borders are usually too faint.

export default {
  name: 'ghostty',
  files(p, { variant, header }) {
    const a = p.ansi
    const slots = [
      a.black, a.red, a.green, a.yellow, a.blue, a.magenta, a.cyan, a.white,
      a.brightBlack, a.brightRed, a.brightGreen, a.brightYellow, a.brightBlue, a.brightMagenta, a.brightCyan, a.brightWhite,
    ]
    return [{
      path: `ghostty/.config/ghostty/themes/${variant.name}`,
      content: `${header('#')}

${slots.map((c, i) => `palette = ${i}=${c}`).join('\n')}
background = ${p.termBg}
foreground = ${p.termFg}
cursor-color = ${p.cursor}
cursor-text = ${p.termBg}
selection-background = ${p.selection}
selection-foreground = ${p.fg}
split-divider-color = ${p.muted}
`,
    }]
  },
}

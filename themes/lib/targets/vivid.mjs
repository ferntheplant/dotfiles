// vivid (LS_COLORS) theme — https://github.com/sharkdp/vivid
//
// File categories borrow the matching syntax role where there is one (source code =
// function, markup = string, tooling = type) and otherwise use the named hues:
// directories blue, symlinks cyan, executables bold green, archives underlined red,
// media magenta, office docs orange, unimportant files muted.

export default {
  name: 'vivid',
  files(p, { stem, header }) {
    const c = hex => `"${hex.slice(1)}"`
    return [{
      path: `vivid/.config/vivid/themes/${stem}.yml`,
      content: `${header('#')}

colors:
  bg: ${c(p.bg)}
  bg_active: ${c(p.bgActive)}
  fg: ${c(p.fg)}
  secondary: ${c(p.fgSecondary)}
  muted: ${c(p.muted)}
  green: ${c(p.green)}
  cyan: ${c(p.cyan)}
  blue: ${c(p.blue)}
  red: ${c(p.red)}
  orange: ${c(p.orange)}
  yellow: ${c(p.yellow)}
  magenta: ${c(p.magenta)}
  string: ${c(p.string)}
  function: ${c(p.function)}
  type: ${c(p.type)}

core:
  normal_text: {}
  regular_file: {}
  reset_to_normal: {}

  directory:
    foreground: blue

  symlink:
    foreground: cyan

  multi_hard_link: {}

  fifo:
    foreground: bg
    background: yellow

  socket:
    foreground: bg
    background: magenta

  door:
    foreground: bg
    background: magenta

  block_device:
    foreground: yellow
    background: bg_active

  character_device:
    foreground: orange
    background: bg_active

  broken_symlink:
    foreground: bg
    background: red

  missing_symlink_target:
    foreground: bg
    background: red

  setuid: {}

  setgid: {}

  file_with_capability: {}

  sticky_other_writable: {}

  other_writable: {}

  sticky: {}

  executable_file:
    foreground: green
    font-style: bold

text:
  special:
    foreground: bg
    background: yellow

  todo:
    font-style: bold

  licenses:
    foreground: secondary

  configuration:
    foreground: yellow

  other:
    foreground: fg

markup:
  foreground: string

programming:
  source:
    foreground: function

  tooling:
    foreground: type

media:
  foreground: magenta

office:
  foreground: orange

archives:
  foreground: red
  font-style: underline

executable:
  foreground: green
  font-style: bold

unimportant:
  foreground: muted
`,
    }]
  },
}

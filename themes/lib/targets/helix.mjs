// Helix theme — https://docs.helix-editor.com/themes.html
//
// Syntax: each Helix scope maps to the palette role for the same construct, and roles resolved
// from TextMate scopes carry their fontStyle (italic comments etc.) over as modifiers.
// Notable choices:
//   - keyword.storage / keyword.function (let, const, function) use `storage`, which VS Code
//     themes style separately from control keywords.
//   - constant.builtin (null/undefined) uses `nullish`; booleans get their own role.
//   - `special` drives fuzzy-match highlights in pickers, so it uses `primary` like VS Code's
//     list.highlightForeground.
// UI: popups/menus/statusline sit on `bgActive` because Helix has no borders to separate them.
// Window splits use `muted`, as theme border colors are usually invisible in a terminal.
// color-modes: normal = primary, insert = blue, select = magenta.

const PALETTE_KEYS = {
  bg: 'bg', bg_active: 'bgActive', fg: 'fg', fg_active: 'fgActive', fg_secondary: 'fgSecondary',
  muted: 'muted', cursor: 'cursor', selection: 'selection', selection_inactive: 'selectionInactive',
  line_highlight: 'lineHighlight', line_nr: 'lineNr', line_nr_active: 'lineNrActive',
  indent_guide: 'indentGuide', whitespace: 'whitespace', find_match: 'findMatch', bracket_match: 'bracketMatch',
  primary: 'primary', error: 'error', warning: 'warning', info: 'info', hint: 'hint',
  red: 'red', green: 'green', yellow: 'yellow', blue: 'blue', magenta: 'magenta', cyan: 'cyan', orange: 'orange',
  comment: 'comment', string: 'string', regex: 'regex', escape: 'escape', number: 'number', boolean: 'boolean',
  nullish: 'nullish', constant: 'constant', variable: 'variable', variable_builtin: 'variableBuiltin',
  parameter: 'parameter', property: 'property', function: 'function', keyword: 'keyword', storage: 'storage',
  operator: 'operator', punctuation: 'punctuation', type: 'type', type_builtin: 'typeBuiltin', class: 'class',
  interface: 'interface', namespace: 'namespace', decorator: 'decorator', tag: 'tag', attribute: 'attribute',
  heading: 'heading', quote: 'quote', raw: 'raw', list_marker: 'listMarker', link_url: 'linkUrl', link_text: 'linkText',
}
const KEY_FOR_ROLE = Object.fromEntries(Object.entries(PALETTE_KEYS).map(([k, v]) => [v, k]))

const SYNTAX = {
  'attribute': 'attribute',
  'type': 'type',
  'type.builtin': 'typeBuiltin',
  'type.enum.variant': 'constant',
  'constructor': 'class',
  'constant': 'constant',
  'constant.builtin': 'nullish',
  'constant.builtin.boolean': 'boolean',
  'constant.character': 'string',
  'constant.character.escape': 'escape',
  'constant.numeric': 'number',
  'string': 'string',
  'string.regexp': 'regex',
  'string.special': 'string',
  'string.special.symbol': 'constant',
  'comment': 'comment',
  'variable': 'variable',
  'variable.builtin': 'variableBuiltin',
  'variable.parameter': 'parameter',
  'variable.other.member': 'property',
  'label': 'namespace',
  'punctuation': 'punctuation',
  'punctuation.special': 'keyword',
  'keyword': 'keyword',
  'keyword.operator': 'operator',
  'keyword.function': 'storage',
  'keyword.storage': 'storage',
  'operator': 'operator',
  'function': 'function',
  'function.macro': 'function',
  'function.special': 'decorator',
  'tag': 'tag',
  'namespace': 'namespace',
  'special': 'primary',
  'markup.list': 'listMarker',
  'markup.link.text': 'linkText',
  'markup.link.label': 'linkText',
  'markup.quote': 'quote',
  'markup.raw': 'raw',
}

const MODIFIERS = { italic: 'italic', bold: 'bold', strikethrough: 'crossed_out' }

function style(p, role, extra = []) {
  const fontStyle = p.fontStyle[role] ?? ''
  const mods = [...new Set([...fontStyle.split(/\s+/).map(s => MODIFIERS[s]).filter(Boolean), ...extra])]
  const underline = /underline/.test(fontStyle) ? ', underline = { style = "line" }' : ''
  const fg = `"${KEY_FOR_ROLE[role]}"`
  if (!mods.length && !underline)
    return fg
  return `{ fg = ${fg}${mods.length ? `, modifiers = [${mods.map(m => `"${m}"`).join(', ')}]` : ''}${underline} }`
}

export default {
  name: 'helix',
  files(p, { stemUs, header }) {
    const syntax = Object.entries(SYNTAX).map(([scope, role]) => `"${scope}" = ${style(p, role)}`).join('\n')
    const palette = Object.entries(PALETTE_KEYS).map(([k, role]) => `${k} = "${p[role]}"`).join('\n')

    return [{
      path: `helix/.config/helix/themes/${stemUs}.toml`,
      content: `${header('#')}

# --- syntax ---------------------------------------------------------------

${syntax}
"markup.heading" = ${style(p, 'heading', ['bold'])}
"markup.bold" = { modifiers = ["bold"] }
"markup.italic" = { modifiers = ["italic"] }
"markup.strikethrough" = { modifiers = ["crossed_out"] }
"markup.link.url" = { fg = "link_url", underline = { style = "line" } }

"diff.plus" = "green"
"diff.minus" = "red"
"diff.delta" = "blue"
"diff.delta.moved" = "cyan"

# --- diagnostics ----------------------------------------------------------

"error" = "error"
"warning" = "warning"
"info" = "info"
"hint" = "hint"

"diagnostic.error" = { underline = { color = "error", style = "curl" } }
"diagnostic.warning" = { underline = { color = "warning", style = "curl" } }
"diagnostic.info" = { underline = { color = "info", style = "curl" } }
"diagnostic.hint" = { underline = { color = "hint", style = "curl" } }
"diagnostic.unnecessary" = { modifiers = ["dim"] }
"diagnostic.deprecated" = { modifiers = ["crossed_out"] }

# --- ui -------------------------------------------------------------------

"ui.background" = { bg = "bg" }
"ui.background.separator" = "muted"
"ui.text" = "fg"
"ui.text.focus" = { fg = "fg", bg = "line_highlight", modifiers = ["bold"] }
"ui.text.inactive" = "fg_secondary"
"ui.text.info" = "fg"
"ui.text.directory" = "blue"

"ui.cursor" = { fg = "bg", bg = "fg_active" }
"ui.cursor.primary" = { fg = "bg", bg = "cursor" }
"ui.cursor.match" = { bg = "bracket_match", modifiers = ["bold"] }
"ui.cursorline.primary" = { bg = "line_highlight" }

"ui.selection" = { bg = "selection_inactive" }
"ui.selection.primary" = { bg = "selection" }
"ui.highlight" = { bg = "find_match" }

"ui.linenr" = "line_nr"
"ui.linenr.selected" = "line_nr_active"
"ui.gutter" = { bg = "bg" }

"ui.statusline" = { fg = "fg_active", bg = "bg_active" }
"ui.statusline.inactive" = { fg = "fg_secondary", bg = "bg" }
"ui.statusline.normal" = { fg = "bg", bg = "primary", modifiers = ["bold"] }
"ui.statusline.insert" = { fg = "bg", bg = "blue", modifiers = ["bold"] }
"ui.statusline.select" = { fg = "bg", bg = "magenta", modifiers = ["bold"] }

"ui.bufferline" = { fg = "fg_secondary", bg = "bg" }
"ui.bufferline.active" = { fg = "fg", bg = "bg_active", underline = { color = "primary", style = "line" } }
"ui.bufferline.background" = { bg = "bg" }

"ui.popup" = { fg = "fg", bg = "bg_active" }
"ui.popup.info" = { fg = "fg", bg = "bg_active" }
"ui.window" = "muted"
"ui.help" = { fg = "fg", bg = "bg_active" }
"ui.menu" = { fg = "fg", bg = "bg_active" }
"ui.menu.selected" = { fg = "fg", bg = "selection" }
"ui.menu.scroll" = { fg = "muted", bg = "bg_active" }
"ui.picker.header" = { fg = "fg_active", modifiers = ["bold"] }

"ui.virtual.ruler" = { bg = "bg_active" }
"ui.virtual.whitespace" = "whitespace"
"ui.virtual.indent-guide" = "indent_guide"
"ui.virtual.inlay-hint" = { fg = "punctuation", bg = "bg_active" }
"ui.virtual.jump-label" = { fg = "orange", modifiers = ["bold"] }
"ui.virtual.wrap" = "muted"

[palette]
${palette}
`,
    }]
  },
}

// Turns one VS Code theme into the flat palette every target (tools/*.mjs) consumes.
//
// Each role below lists where its color can come from, tried in order. The first source that
// exists and isn't fully transparent wins:
//
//   'ui:<key>'        a workbench color from the theme's `colors`
//   'scope:<scope>'   what the theme's tokenColors give that TextMate scope (see vscode.mjs)
//   'semantic:<tok>'  a semanticTokenColors entry
//   'role:<name>'     another role from this table
//   'mix:<a>:<b>:<n>' role a laid over role b at n (0..1) — last-resort derived colors for
//                     sparse themes that define few workbench colors
//   '#rrggbb'         a literal
//
// Roles marked `optional` may come out undefined. Roles marked `distinct` skip candidates
// identical to `bg` (e.g. a theme whose widget background equals the editor background gives
// no usable "raised surface").
//
// A theme's theme.json can override any role (see README.md). Overrides take priority over
// the table, and roles that fall back to an overridden role pick up the override too.
//
// Every color is flattened to opaque #rrggbb: translucent colors are blended onto `bg`
// (terminal colors onto `termBg`).

import { alpha, blend, isHex, luminance, mix } from './color.mjs'
import { createScopeResolver, semanticColor } from './vscode.mjs'

export const ROLES = {
  // --- surfaces ---------------------------------------------------------------------------
  bg: ['ui:editor.background', 'ui:background', 'role:termBg'],
  bgActive: { distinct: true, from: ['ui:input.background', 'ui:list.hoverBackground', 'ui:editorWidget.background', 'ui:editor.lineHighlightBackground', 'ui:sideBar.background', 'mix:fg:bg:0.06'] },
  border: ['ui:editorGroup.border', 'ui:panel.border', 'ui:sideBar.border', 'ui:contrastBorder', 'mix:fg:bg:0.1'],
  lineHighlight: { distinct: true, from: ['ui:editor.lineHighlightBackground', 'role:bgActive'] },
  selection: ['ui:editor.selectionBackground', 'ui:selection.background', 'mix:fg:bg:0.15'],
  selectionInactive: ['ui:editor.inactiveSelectionBackground', 'ui:editor.selectionHighlightBackground', 'role:selection'],
  findMatch: ['ui:editor.findMatchBackground', 'role:selection'],
  findMatchHighlight: ['ui:editor.findMatchHighlightBackground', 'role:findMatch'],
  bracketMatch: ['ui:editorBracketMatch.background', 'role:selectionInactive'],
  // optional: targets derive a tint of green/red when the theme has no diff colors
  diffInserted: { optional: true, from: ['ui:diffEditor.insertedTextBackground', 'ui:diffEditor.insertedLineBackground'] },
  diffRemoved: { optional: true, from: ['ui:diffEditor.removedTextBackground', 'ui:diffEditor.removedLineBackground'] },

  // --- text -------------------------------------------------------------------------------
  fg: ['ui:editor.foreground', 'ui:foreground', 'role:termFg'],
  fgActive: ['ui:sideBar.foreground', 'ui:statusBar.foreground', 'ui:list.activeSelectionForeground', 'role:fg'],
  fgSecondary: ['ui:descriptionForeground', 'ui:tab.inactiveForeground', 'role:fgActive'],
  muted: ['ui:editorLineNumber.foreground', 'ui:activityBar.inactiveForeground', 'ui:disabledForeground', 'mix:fg:bg:0.4'],
  cursor: ['ui:editorCursor.foreground', 'ui:terminalCursor.foreground', 'role:fg'],
  lineNr: ['ui:editorLineNumber.foreground', 'role:muted'],
  lineNrActive: ['ui:editorLineNumber.activeForeground', 'role:fgActive'],
  indentGuide: ['ui:editorIndentGuide.background1', 'ui:editorIndentGuide.background', 'role:border'],
  indentGuideActive: ['ui:editorIndentGuide.activeBackground1', 'ui:editorIndentGuide.activeBackground', 'role:muted'],
  whitespace: ['ui:editorWhitespace.foreground', 'role:indentGuide'],

  // --- accents ----------------------------------------------------------------------------
  // The theme's own highlight color: buttons, links, focused tabs.
  primary: ['ui:button.background', 'ui:textLink.foreground', 'ui:focusBorder', 'ui:activityBar.activeBorder', 'role:keyword'],
  // Named hues come from the terminal palette, which nearly every theme defines, and fall
  // back to the git/diagnostic colors, which are usually the same hues.
  red: ['ui:terminal.ansiRed', 'ui:editorError.foreground', 'ui:gitDecoration.deletedResourceForeground', '#cc6666'],
  green: ['ui:terminal.ansiGreen', 'ui:gitDecoration.addedResourceForeground', '#8fa060'],
  yellow: ['ui:terminal.ansiYellow', 'ui:editorWarning.foreground', '#d0b060'],
  blue: ['ui:terminal.ansiBlue', 'ui:editorInfo.foreground', 'ui:gitDecoration.modifiedResourceForeground', '#6a95c0'],
  magenta: ['ui:terminal.ansiMagenta', 'role:keyword'],
  cyan: ['ui:terminal.ansiCyan', 'ui:gitDecoration.untrackedResourceForeground', 'role:blue'],
  // There's no ANSI orange, so this uses the warning color when it differs from yellow.
  orange: ['ui:editorWarning.foreground', 'ui:gitDecoration.conflictingResourceForeground', 'ui:notificationsWarningIcon.foreground', 'role:yellow'],

  error: ['ui:editorError.foreground', 'ui:errorForeground', 'role:red'],
  warning: ['ui:editorWarning.foreground', 'role:orange'],
  info: ['ui:editorInfo.foreground', 'role:blue'],
  hint: ['ui:editorHint.foreground', 'role:green'],

  // Rainbow-bracket levels 1–6
  bracket1: ['ui:editorBracketHighlight.foreground1', 'role:cyan'],
  bracket2: ['ui:editorBracketHighlight.foreground2', 'role:green'],
  bracket3: ['ui:editorBracketHighlight.foreground3', 'role:orange'],
  bracket4: ['ui:editorBracketHighlight.foreground4', 'role:magenta'],
  bracket5: ['ui:editorBracketHighlight.foreground5', 'role:yellow'],
  bracket6: ['ui:editorBracketHighlight.foreground6', 'role:blue'],

  // --- syntax -----------------------------------------------------------------------------
  // Scopes are the ones VS Code's TypeScript/Markdown grammars emit for the construct.
  comment: ['scope:comment.line.double-slash', 'scope:comment', 'role:muted'],
  string: ['scope:string.quoted.double', 'scope:string', 'role:green'],
  regex: ['scope:string.regexp', 'role:string'],
  escape: ['scope:constant.character.escape', 'role:constant'],
  number: ['scope:constant.numeric', 'role:constant'],
  boolean: ['scope:constant.language.boolean', 'role:constant'],
  nullish: ['scope:constant.language.null', 'scope:constant.language', 'role:constant'],
  constant: ['scope:constant.other', 'scope:variable.other.constant', 'scope:constant', 'role:orange'],
  variable: ['scope:variable.other.readwrite', 'scope:variable', 'role:fg'],
  variableBuiltin: ['scope:variable.language.this', 'scope:variable.language', 'role:variable'],
  parameter: ['scope:variable.parameter.function', 'scope:variable.parameter', 'role:variable'],
  property: ['semantic:property', 'scope:meta.object-literal.key', 'scope:variable.other.property', 'role:variable'],
  function: ['scope:entity.name.function', 'scope:support.function', 'role:blue'],
  keyword: ['scope:keyword.control', 'scope:keyword', 'role:magenta'],
  storage: ['scope:storage.type', 'scope:storage', 'role:keyword'],
  operator: ['scope:keyword.operator.logical', 'scope:keyword.operator', 'role:punctuation'],
  punctuation: ['scope:punctuation.separator', 'scope:punctuation', 'role:fgSecondary'],
  type: ['scope:entity.name.type', 'semantic:type', 'role:yellow'],
  typeBuiltin: ['scope:support.type.primitive', 'scope:support.type', 'role:type'],
  class: ['semantic:class', 'scope:entity.name.type.class', 'role:type'],
  interface: ['semantic:interface', 'scope:entity.name.type.interface', 'role:type'],
  namespace: ['semantic:namespace', 'scope:entity.name.type.module', 'scope:entity.name.namespace', 'role:type'],
  decorator: ['scope:meta.decorator', 'scope:entity.name.function.decorator', 'role:function'],
  tag: ['scope:entity.name.tag', 'role:keyword'],
  attribute: ['scope:entity.other.attribute-name', 'role:property'],

  // --- markup (markdown) ------------------------------------------------------------------
  heading: ['scope:markup.heading', 'scope:entity.name.section', 'role:primary'],
  quote: ['scope:markup.quote', 'role:comment'],
  raw: ['scope:markup.inline.raw', 'scope:markup.raw', 'role:string'],
  listMarker: ['scope:punctuation.definition.list.begin.markdown', 'role:punctuation'],
  linkUrl: ['scope:markup.underline.link', 'role:fgSecondary'],
  linkText: ['scope:string.other.link', 'role:string'],

  // --- terminal (VS Code integrated terminal) ---------------------------------------------
  termBg: ['ui:terminal.background', 'ui:editor.background', 'ui:background', '#000000'],
  termFg: ['ui:terminal.foreground', 'ui:editor.foreground', 'ui:foreground', '#ffffff'],
}

// Named ANSI slots, fed from terminal.ansi* with the accents as fallback.
const ANSI = {
  black: ['ui:terminal.ansiBlack', 'role:bgActive'],
  red: ['ui:terminal.ansiRed', 'role:red'],
  green: ['ui:terminal.ansiGreen', 'role:green'],
  yellow: ['ui:terminal.ansiYellow', 'role:yellow'],
  blue: ['ui:terminal.ansiBlue', 'role:blue'],
  magenta: ['ui:terminal.ansiMagenta', 'role:magenta'],
  cyan: ['ui:terminal.ansiCyan', 'role:cyan'],
  white: ['ui:terminal.ansiWhite', 'role:fg'],
  brightBlack: ['ui:terminal.ansiBrightBlack', 'role:muted'],
  brightRed: ['ui:terminal.ansiBrightRed', 'role:red'],
  brightGreen: ['ui:terminal.ansiBrightGreen', 'role:green'],
  brightYellow: ['ui:terminal.ansiBrightYellow', 'role:yellow'],
  brightBlue: ['ui:terminal.ansiBrightBlue', 'role:blue'],
  brightMagenta: ['ui:terminal.ansiBrightMagenta', 'role:magenta'],
  brightCyan: ['ui:terminal.ansiBrightCyan', 'role:cyan'],
  brightWhite: ['ui:terminal.ansiBrightWhite', 'role:fg'],
}

// Where each role's translucent color gets flattened onto.
const UNDERLAY = { bg: '#000000', termBg: '#000000', termFg: 'termBg' }
const underlayOf = name => UNDERLAY[name] ?? (name.startsWith('ansi.') ? 'termBg' : 'bg')

/**
 * @param {object} vscode  theme from loadVscodeTheme()
 * @param {object} opts    { overrides: {role: '#hex' | 'role:x'}, mode?: 'dark'|'light' }
 */
export function buildPalette(vscode, { overrides = {}, mode } = {}) {
  const resolveScope = createScopeResolver(vscode)
  const values = {}
  const sources = {} // role -> the source that won, for `build.mjs --explain`
  const fontStyle = {}
  const resolving = new Set()

  const table = { ...ROLES }
  for (const [k, v] of Object.entries(ANSI)) table[`ansi.${k}`] = v

  function candidate(source) {
    if (isHex(source))
      return { color: source }
    const [kind, ...rest] = source.split(':')
    const key = rest.join(':')
    if (kind === 'ui')
      return vscode.colors[key] ? { color: vscode.colors[key] } : null
    if (kind === 'semantic') {
      const c = semanticColor(vscode, key)
      return c ? { color: c } : null
    }
    if (kind === 'scope') {
      const r = resolveScope(key)
      return r.foreground ? { color: r.foreground, fontStyle: r.fontStyle } : null
    }
    if (kind === 'role')
      return { color: get(key), flat: true }
    if (kind === 'mix') {
      const [a, b, amount] = rest
      return { color: mix(get(a), get(b), Number(amount)), flat: true }
    }
    throw new Error(`Unknown palette source: ${source}`)
  }

  function get(name) {
    if (name in values)
      return values[name]
    if (!(name in table))
      throw new Error(`Unknown palette role: ${name}`)
    if (resolving.has(name))
      throw new Error(`Palette roles reference each other in a loop: ${[...resolving, name].join(' -> ')}`)
    resolving.add(name)

    const spec = Array.isArray(table[name]) ? { from: table[name] } : table[name]
    const chain = overrides[name] ? [overrides[name], ...spec.from] : spec.from
    const under = underlayOf(name)
    const underColor = isHex(under) ? under : get(under)

    for (const source of chain) {
      const c = candidate(source)
      if (!c || !isHex(c.color) || alpha(c.color) === 0)
        continue
      const color = c.flat ? c.color : blend(c.color, underColor)
      if (spec.distinct && name !== 'bg' && color === get('bg'))
        continue
      values[name] = color
      sources[name] = source === overrides[name] ? `override ${source}` : source
      if (c.fontStyle)
        fontStyle[name] = c.fontStyle
      break
    }
    resolving.delete(name)
    if (!(name in values) && spec.optional)
      values[name] = undefined
    if (!(name in values))
      throw new Error(`No source for palette role "${name}"; add an override in theme.json`)
    return values[name]
  }

  const p = { fontStyle, sources, ansi: {} }
  for (const name of Object.keys(ROLES))
    p[name] = get(name)
  for (const name of Object.keys(ANSI))
    p.ansi[name] = get(`ansi.${name}`)

  const detected = vscode.type === 'light' || vscode.base === 'vs'
    ? 'light'
    : vscode.type === 'dark' || vscode.base === 'vs-dark'
      ? 'dark'
      : luminance(p.bg) < 0.18 ? 'dark' : 'light'
  p.mode = mode ?? detected
  p.isDark = p.mode === 'dark'
  return p
}

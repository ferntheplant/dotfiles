// Reading Zed themes (https://zed.dev/docs/extensions/themes) as if they were VS Code themes.
//
// A Zed theme file is a family: { themes: [{ name, appearance, style }] }. One entry is
// translated into the shape loadVscodeTheme() returns, so the palette table and every target
// work on it unchanged:
//
//   - `style` keys are renamed to the VS Code workbench keys palette.mjs reads (ZED_UI below).
//     Where several Zed keys feed one VS Code key, the first one the theme sets wins.
//   - `players[0]` is the local user: its cursor and selection become the editor's.
//   - `accents` (Zed's rainbow brackets/indent guides) become editorBracketHighlight.*.
//   - `syntax` captures (tree-sitter names) become tokenColors rules for the TextMate scopes
//     VS Code grammars emit for the same construct (ZED_SYNTAX below). Zed falls back from
//     `keyword.import` to `keyword` the way TextMate falls back from `keyword.control.import`
//     to `keyword`, so unlisted captures still resolve through their parent.
//
// Zed themes may be translucent all the way down (`background.appearance: blurred`). A
// terminal can't show through itself, so the window backgrounds (editor and terminal) are
// made opaque by dropping their alpha: the tint the theme picked, without whatever's behind
// the window. Everything else is flattened onto them as usual.

import { parseHex, toHex } from './color.mjs'
import { parseJsonc } from './vscode.mjs'

export const isZedTheme = json => Array.isArray(json?.themes) && json.themes.some(t => t?.style)

// VS Code key <- Zed keys, in order of preference.
const ZED_UI = {
  'editor.background': ['editor.background', 'background'],
  'editor.foreground': ['editor.foreground', 'text'],
  'foreground': ['text'],
  'sideBar.background': ['panel.background', 'background'],
  'sideBar.foreground': ['text'],
  'descriptionForeground': ['text.muted'],
  'disabledForeground': ['text.disabled'],
  'textLink.foreground': ['text.accent', 'link_text.hover'],
  'focusBorder': ['border.focused'],
  'editorGroup.border': ['pane_group.border', 'border'],
  'panel.border': ['border.variant', 'border'],
  'input.background': ['element.background'],
  'list.hoverBackground': ['element.hover', 'ghost_element.hover'],
  'editorWidget.background': ['elevated_surface.background', 'panel.overlay_background'],
  'editor.lineHighlightBackground': ['editor.active_line.background'],
  'editor.selectionHighlightBackground': ['editor.document_highlight.read_background'],
  'editor.findMatchBackground': ['search.active_match_background', 'search.match_background'],
  'editor.findMatchHighlightBackground': ['search.match_background'],
  'editorBracketMatch.background': ['editor.document_highlight.bracket_background'],
  'editorLineNumber.foreground': ['editor.line_number'],
  'editorLineNumber.activeForeground': ['editor.active_line_number'],
  'editorIndentGuide.background1': ['editor.indent_guide'],
  'editorIndentGuide.activeBackground1': ['editor.indent_guide_active'],
  'editorWhitespace.foreground': ['editor.invisible'],
  'editorError.foreground': ['error'],
  'editorWarning.foreground': ['warning'],
  'editorInfo.foreground': ['info'],
  'editorHint.foreground': ['hint'],
  'diffEditor.insertedTextBackground': ['version_control.word_added'],
  'diffEditor.insertedLineBackground': ['created.background'],
  'diffEditor.removedTextBackground': ['version_control.word_deleted'],
  'diffEditor.removedLineBackground': ['deleted.background'],
  'gitDecoration.addedResourceForeground': ['version_control.added', 'created'],
  'gitDecoration.modifiedResourceForeground': ['version_control.modified', 'modified'],
  'gitDecoration.deletedResourceForeground': ['version_control.deleted', 'deleted'],
  'gitDecoration.conflictingResourceForeground': ['version_control.conflict', 'conflict'],
  'gitDecoration.ignoredResourceForeground': ['version_control.ignored', 'ignored'],
  'terminal.background': ['terminal.background', 'terminal.ansi.background'],
  'terminal.foreground': ['terminal.foreground'],
}
const ANSI_NAMES = ['black', 'red', 'green', 'yellow', 'blue', 'magenta', 'cyan', 'white']
const cap = s => s[0].toUpperCase() + s.slice(1)
for (const n of ANSI_NAMES) {
  ZED_UI[`terminal.ansi${cap(n)}`] = [`terminal.ansi.${n}`]
  ZED_UI[`terminal.ansiBright${cap(n)}`] = [`terminal.ansi.bright_${n}`]
}

// Zed capture -> TextMate scopes. Ordered general to specific: rules for the same scope
// resolve by order, so a specific capture (`keyword.import`) wins over its parent.
const ZED_SYNTAX = [
  ['comment', ['comment', 'punctuation.definition.comment']],
  ['comment.doc', ['comment.block.documentation']],
  ['string', ['string', 'punctuation.definition.string']],
  ['string.special', ['string.other', 'string.interpolated']],
  ['string.special.symbol', ['constant.other.symbol']],
  ['string.regex', ['string.regexp']],
  ['string.regexp', ['string.regexp']],
  ['string.escape', ['constant.character.escape']],
  ['constant', ['constant', 'variable.other.constant']],
  ['number', ['constant.numeric']],
  ['boolean', ['constant.language.boolean']],
  ['constant.builtin', ['constant.language']],
  ['variable', ['variable', 'variable.other.readwrite']],
  ['parameter', ['variable.parameter']],
  ['variable.parameter', ['variable.parameter']],
  ['variable.special', ['variable.language']],
  ['variable.builtin', ['variable.language']],
  ['variant', ['variable.other.enummember']],
  ['property', ['variable.other.property', 'meta.object-literal.key', 'support.type.property-name', 'support.variable.property']],
  ['property.json_key', ['support.type.property-name.json']],
  ['function', ['entity.name.function', 'support.function', 'meta.function-call']],
  ['function.method', ['entity.name.function.method']],
  ['constructor', ['entity.name.function.constructor']],
  ['decorator', ['meta.decorator', 'entity.name.function.decorator']],
  ['function.decorator', ['meta.decorator', 'entity.name.function.decorator']],
  ['keyword', ['keyword', 'storage']],
  ['keyword.control', ['keyword.control']],
  ['keyword.conditional', ['keyword.control.conditional']],
  ['keyword.repeat', ['keyword.control.loop']],
  ['keyword.return', ['keyword.control.flow']],
  ['keyword.exception', ['keyword.control.trycatch']],
  ['keyword.import', ['keyword.control.import', 'keyword.control.export']],
  ['keyword.export', ['keyword.control.export']],
  ['keyword.function', ['storage.type.function']],
  ['keyword.modifier', ['storage.modifier']],
  ['keyword.type', ['storage.type']],
  ['operator', ['keyword.operator']],
  ['keyword.operator', ['keyword.operator.expression', 'keyword.operator.new']],
  ['punctuation', ['punctuation', 'meta.brace']],
  ['punctuation.bracket', ['punctuation.section', 'meta.brace']],
  ['punctuation.delimiter', ['punctuation.separator', 'punctuation.terminator']],
  ['punctuation.special', ['punctuation.definition.template-expression', 'punctuation.section.embedded']],
  ['punctuation.list_marker', ['punctuation.definition.list']],
  ['type', ['entity.name.type', 'support.type', 'support.class']],
  ['type.builtin', ['support.type.primitive', 'support.type.builtin']],
  ['class', ['entity.name.type.class']],
  ['type.class.definition', ['entity.name.type.class']],
  ['interface', ['entity.name.type.interface']],
  ['type.interface', ['entity.name.type.interface']],
  ['enum', ['entity.name.type.enum']],
  ['namespace', ['entity.name.type.module', 'entity.name.namespace']],
  ['module', ['entity.name.type.module', 'entity.name.namespace']],
  ['label', ['entity.name.label']],
  ['tag', ['entity.name.tag']],
  ['attribute', ['entity.other.attribute-name']],
  ['selector', ['entity.name.tag.css', 'entity.other.attribute-name.class.css', 'entity.other.attribute-name.id.css']],
  ['selector.pseudo', ['entity.other.attribute-name.pseudo-class', 'entity.other.attribute-name.pseudo-element']],
  ['preproc', ['meta.preprocessor']],
  ['embedded', ['meta.embedded']],
  ['title', ['markup.heading', 'entity.name.section']],
  ['emphasis', ['markup.italic']],
  ['emphasis.strong', ['markup.bold']],
  ['text.literal', ['markup.inline.raw', 'markup.raw', 'markup.fenced_code']],
  ['link_text', ['string.other.link', 'markup.underline.link.text']],
  ['link_uri', ['markup.underline.link']],
]

const opaque = hex => toHex(parseHex(hex))

function fontStyleOf({ font_style, font_weight }) {
  const parts = []
  if (font_style === 'italic' || font_style === 'oblique')
    parts.push('italic')
  if (font_weight >= 600)
    parts.push('bold')
  return parts.length ? parts.join(' ') : undefined
}

/** One theme of a Zed theme family, as a VS Code theme (see loadVscodeTheme). */
export function zedToVscode(json, file, name) {
  const entry = name
    ? json.themes.find(t => t.name === name)
    : json.themes.length === 1 ? json.themes[0] : undefined
  if (!entry) {
    const names = json.themes.map(t => `"${t.name}"`).join(', ')
    throw new Error(`${file}: ${name ? `no theme named "${name}"` : 'several themes in this file; pick one with "theme"'} (has ${names})`)
  }
  const style = entry.style ?? {}
  const set = v => typeof v === 'string' && v !== ''

  const colors = {}
  for (const [vscodeKey, zedKeys] of Object.entries(ZED_UI)) {
    const key = zedKeys.find(k => set(style[k]))
    if (key)
      colors[vscodeKey] = style[key]
  }
  for (const k of ['editor.background', 'terminal.background']) {
    if (colors[k])
      colors[k] = opaque(colors[k])
  }
  const me = style.players?.[0] ?? {}
  if (set(me.cursor))
    colors['editorCursor.foreground'] = me.cursor
  if (set(me.selection))
    colors['editor.selectionBackground'] = me.selection
  ;(style.accents ?? []).slice(0, 6).forEach((c, i) => {
    if (set(c))
      colors[`editorBracketHighlight.foreground${i + 1}`] = c
  })

  const syntax = style.syntax ?? {}
  const tokenColors = []
  if (colors['editor.foreground'])
    tokenColors.push({ settings: { foreground: colors['editor.foreground'] } })
  for (const [capture, scope] of ZED_SYNTAX) {
    const s = syntax[capture]
    if (!s)
      continue
    const settings = {}
    if (set(s.color))
      settings.foreground = s.color
    const fontStyle = fontStyleOf(s)
    if (fontStyle)
      settings.fontStyle = fontStyle
    if (Object.keys(settings).length)
      tokenColors.push({ name: `zed: ${capture}`, scope, settings })
  }

  return {
    name: entry.name,
    type: entry.appearance,
    colors,
    tokenColors,
    semanticTokenColors: {},
  }
}

// bat (and delta's syntax-theme) — a TextMate .tmTheme converted straight from the VS Code
// theme's tokenColors, so syntax highlighting is exactly the theme's own rules. Only the
// global settings (background, gutter, selection...) come from the palette.
//
// bat treats alpha specially (0 means "use ANSI color"), so every color is written opaque.

import { blend } from '../color.mjs'

const xml = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
const dict = (entries, indent) => entries
  .filter(([, v]) => v !== undefined && v !== null)
  .map(([k, v]) => `${indent}<key>${xml(k)}</key>\n${indent}<string>${xml(v)}</string>`)
  .join('\n')

export default {
  name: 'bat',
  files(p, { vscode, variant, stem, headerText }) {
    const globals = [
      ['background', p.bg],
      ['foreground', p.fg],
      ['caret', p.cursor],
      ['invisibles', p.whitespace],
      ['lineHighlight', p.lineHighlight],
      ['selection', p.selection],
      ['selectionBorder', p.selection],
      ['inactiveSelection', p.selectionInactive],
      ['findHighlight', p.findMatch],
      ['gutter', p.bg],
      ['gutterForeground', p.lineNr],
      ['guide', p.indentGuide],
      ['activeGuide', p.indentGuideActive],
      ['bracketsForeground', p.fgSecondary],
      ['bracketContentsForeground', p.fgSecondary],
    ]

    const rules = vscode.tokenColors.map((rule) => {
      const s = rule.settings ?? {}
      const settings = [
        ['foreground', s.foreground && blend(s.foreground, p.bg)],
        ['background', s.background && blend(s.background, p.bg)],
        ['fontStyle', s.fontStyle === undefined ? undefined : s.fontStyle === 'normal' ? '' : s.fontStyle],
      ].filter(([, v]) => v !== undefined)
      if (!settings.length || rule.scope === undefined)
        return ''
      const scope = Array.isArray(rule.scope) ? rule.scope.join(', ') : rule.scope
      return `\t\t<dict>
\t\t\t<key>scope</key>
\t\t\t<string>${xml(scope)}</string>
\t\t\t<key>settings</key>
\t\t\t<dict>
${dict(settings, '\t\t\t\t')}
\t\t\t</dict>
\t\t</dict>`
    }).filter(Boolean)

    return [{
      path: `bat/.config/bat/themes/${stem}.tmTheme`,
      content: `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<!-- ${xml(headerText)} -->
<plist version="1.0">
<dict>
\t<key>name</key>
\t<string>${xml(variant.name)}</string>
\t<key>semanticClass</key>
\t<string>theme.${p.mode}.${stem}</string>
\t<key>settings</key>
\t<array>
\t\t<dict>
\t\t\t<key>settings</key>
\t\t\t<dict>
${dict(globals, '\t\t\t\t')}
\t\t\t</dict>
\t\t</dict>
${rules.join('\n')}
\t</array>
</dict>
</plist>
`,
    }]
  },
}

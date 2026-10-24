// Loading VS Code color themes and answering "what color does this theme give scope X?"

import { readFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'

// VS Code theme files are JSONC: comments and trailing commas are allowed.
export function parseJsonc(text) {
  let out = ''
  let inString = false
  for (let i = 0; i < text.length; i++) {
    const c = text[i]
    if (inString) {
      out += c
      if (c === '\\')
        out += text[++i] ?? ''
      else if (c === '"')
        inString = false
    }
    else if (c === '"') {
      inString = true
      out += c
    }
    else if (c === '/' && text[i + 1] === '/') {
      while (i < text.length && text[i] !== '\n') i++
      out += '\n'
    }
    else if (c === '/' && text[i + 1] === '*') {
      i += 2
      while (i < text.length && !(text[i] === '*' && text[i + 1] === '/')) i++
      i++
    }
    else {
      out += c
    }
  }
  return JSON.parse(out.replace(/,(\s*[}\]])/g, '$1'))
}

// Load a theme, following `include` (a base theme the file extends). Colors from the
// including file win; its token rules are appended after the base's so they win ties.
export function loadVscodeTheme(file) {
  const theme = parseJsonc(readFileSync(file, 'utf8'))
  if (typeof theme.tokenColors === 'string')
    throw new Error(`${file}: tokenColors points at ${theme.tokenColors}; convert that .tmTheme to JSON tokenColors first`)

  let base = { colors: {}, tokenColors: [], semanticTokenColors: {} }
  if (theme.include)
    base = loadVscodeTheme(resolve(dirname(file), theme.include))

  return {
    name: theme.name,
    type: theme.type,
    base: theme.base, // monaco-style "vs" / "vs-dark", used by some generators instead of `type`
    colors: { ...base.colors, ...theme.colors },
    tokenColors: [...base.tokenColors, ...(theme.tokenColors ?? [])],
    semanticTokenColors: { ...base.semanticTokenColors, ...(theme.semanticTokenColors ?? {}) },
  }
}

// Normalize tokenColors into flat single-scope selectors so they can be matched. Descendant
// selectors ("string variable") and exclusions ("a - b") only apply in context, so they're
// skipped: we're asking what a scope looks like on its own.
function flatRules(tokenColors) {
  const rules = []
  tokenColors.forEach((rule, order) => {
    if (!rule.settings)
      return
    const scopes = rule.scope === undefined
      ? [''] // a rule with no scope sets the defaults
      : (Array.isArray(rule.scope) ? rule.scope : String(rule.scope).split(','))
    for (const raw of scopes) {
      const selector = raw.trim()
      if (/\s/.test(selector))
        continue
      rules.push({ selector, order, settings: rule.settings })
    }
  })
  return rules
}

// TextMate matching for one scope: a selector matches when it equals the scope or is a
// dot-segment prefix of it. The most specific (most segments) match wins, later rules break
// ties. foreground and fontStyle are resolved independently, like VS Code does.
export function createScopeResolver(theme) {
  const rules = flatRules(theme.tokenColors)
  const cache = new Map()

  return function resolveScope(scope) {
    if (cache.has(scope))
      return cache.get(scope)
    const result = {}
    for (const key of ['foreground', 'fontStyle']) {
      let best = null
      for (const r of rules) {
        if (r.settings[key] === undefined)
          continue
        if (r.selector && r.selector !== scope && !scope.startsWith(`${r.selector}.`))
          continue
        const specificity = r.selector ? r.selector.split('.').length : 0
        if (!best || specificity > best.specificity || (specificity === best.specificity && r.order >= best.order))
          best = { specificity, order: r.order, value: r.settings[key] }
      }
      // A match on the empty selector is just the default foreground, which doesn't count as the
      // theme styling this scope.
      if (best && best.specificity > 0)
        result[key] = best.value
    }
    cache.set(scope, result)
    return result
  }
}

// Semantic token colors can be a string or { foreground, fontStyle/bold/italic }.
export function semanticColor(theme, token) {
  const v = theme.semanticTokenColors?.[token]
  if (!v)
    return undefined
  return typeof v === 'string' ? v : v.foreground
}

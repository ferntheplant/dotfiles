// zsh-syntax-highlighting styles and fzf colors, sourced by the `theme` shell function.
//
// Shell tokens map onto the syntax role of the closest code construct:
//   commands/aliases/functions = function calls   builtins/precommands = storage keywords
//   reserved words (if, for) = keyword            options (-f, --flag) = constant
//   assignments/$params = variable                 strings = string, globs = regex
//   redirections = operator                        separators (; && |) = punctuation
// Bracket levels use the theme's rainbow-bracket colors.
//
// fzf: matches use primary (VS Code's list.highlightForeground idea), the focused row uses
// the line highlight.

export default {
  name: 'zsh',
  files(p, { stemUs, header }) {
    const s = {
      'default': `fg=${p.fg}`,
      'unknown-token': `fg=${p.error}`,
      'reserved-word': `fg=${p.keyword}`,
      'alias': `fg=${p.function}`,
      'suffix-alias': `fg=${p.function}`,
      'global-alias': `fg=${p.function}`,
      'builtin': `fg=${p.storage}`,
      'function': `fg=${p.function}`,
      'command': `fg=${p.function}`,
      'hashed-command': `fg=${p.function}`,
      'precommand': `fg=${p.storage},italic`,
      'commandseparator': `fg=${p.punctuation}`,
      'autodirectory': `fg=${p.fg},underline`,

      'single-hyphen-option': `fg=${p.constant}`,
      'double-hyphen-option': `fg=${p.constant}`,
      'back-quoted-option': `fg=${p.constant}`,
      'assign': `fg=${p.variable}`,
      'named-fd': `fg=${p.number}`,
      'numeric-fd': `fg=${p.number}`,
      'dollar-parameter': `fg=${p.variable}`,
      'dollar-parameter-brace': `fg=${p.variable}`,
      'parameter': `fg=${p.variable}`,
      'parameter-brace': `fg=${p.punctuation}`,
      'parameter-expansion': `fg=${p.variable}`,
      'parameter-flag': `fg=${p.operator}`,
      'default-param': `fg=${p.fgSecondary}`,

      'single-quoted-argument': `fg=${p.string}`,
      'single-quoted-argument-unclosed': `fg=${p.error}`,
      'double-quoted-argument': `fg=${p.string}`,
      'double-quoted-argument-unclosed': `fg=${p.error}`,
      'dollar-double-quoted-argument': `fg=${p.variable}`,
      'dollar-double-quoted-argument-unclosed': `fg=${p.error}`,
      'dollar-quoted-argument': `fg=${p.string}`,
      'dollar-quoted-argument-unclosed': `fg=${p.error}`,
      'back-quoted-argument': `fg=${p.keyword}`,
      'back-quoted-argument-unclosed': `fg=${p.error}`,
      'back-quoted-argument-delimiter': `fg=${p.keyword}`,
      'back-double-quoted-argument': `fg=${p.escape}`,
      'back-dollar-quoted-argument': `fg=${p.escape}`,
      'rc-quote': `fg=${p.escape}`,

      'globbing': `fg=${p.regex}`,
      'history-expansion': `fg=${p.magenta}`,
      'back-reference': `fg=${p.regex}`,
      'path': `fg=${p.fg},underline`,
      'path_prefix': `fg=${p.fg},underline`,
      'path_approx': `fg=${p.fg}`,
      'path_pathseparator': `fg=${p.punctuation},underline`,
      'path_prefix_pathseparator': `fg=${p.punctuation},underline`,
      'command-substitution': `fg=${p.fg}`,
      'command-substitution-delimiter': `fg=${p.keyword}`,
      'command-substitution-unquoted': `fg=${p.fg}`,
      'command-substitution-delimiter-unquoted': `fg=${p.keyword}`,
      'command-substitution-quoted': `fg=${p.string}`,
      'command-substitution-delimiter-quoted': `fg=${p.keyword}`,
      'process-substitution': `fg=${p.fg}`,
      'process-substitution-delimiter': `fg=${p.keyword}`,
      'arithmetic-expansion': `fg=${p.number}`,

      'comment': `fg=${p.comment}`,
      'redirection': `fg=${p.operator}`,

      'bracket-error': `fg=${p.error},bold`,
      'bracket-level-1': `fg=${p.bracket1}`,
      'bracket-level-2': `fg=${p.bracket2}`,
      'bracket-level-3': `fg=${p.bracket3}`,
      'bracket-level-4': `fg=${p.bracket4}`,
      'bracket-level-5': `fg=${p.bracket5}`,
      'bracket-level-6': `fg=${p.bracket6}`,
      'cursor-matchingbracket': `bg=${p.bracketMatch}`,
    }

    return [
      {
        path: `zsh/.zsh/${stemUs}-zsh-syntax-highlighting.zsh`,
        content: `${header('#')}

typeset -gA ZSH_HIGHLIGHT_STYLES

${Object.entries(s).map(([k, v]) => `ZSH_HIGHLIGHT_STYLES[${k}]="${v}"`).join('\n')}
`,
      },
      {
        path: `zsh/.zsh/${stemUs}-fzf.zsh`,
        content: `${header('#')}

export FZF_DEFAULT_OPTS="
--color=fg:${p.fgActive},bg:${p.bg},hl:${p.primary}
--color=fg+:${p.fg},bg+:${p.lineHighlight},hl+:${p.primary}
--color=border:${p.muted},header:${p.blue},gutter:${p.bg}
--color=spinner:${p.yellow},info:${p.cyan},separator:${p.muted}
--color=pointer:${p.primary},marker:${p.magenta},prompt:${p.fgSecondary}"
`,
      },
    ]
  },
}

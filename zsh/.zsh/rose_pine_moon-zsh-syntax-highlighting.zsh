# Rosé Pine Moon theme for zsh-syntax-highlighting
# Palette reference: Base16 Rosé Pine Moon (https://github.com/edunfelt/base16-rose-pine-scheme)

typeset -gA _rose_pine_moon_palette=(
  base           '#232136'
  surface        '#2a273f'
  overlay        '#393552'
  muted          '#6e6a86'
  subtle         '#908caa'
  text           '#e0def4'
  love           '#eb6f92'
  gold           '#f6c177'
  rose           '#ea9a97'
  pine           '#3e8fb0'
  foam           '#9ccfd8'
  iris           '#c4a7e7'
  highlight_low  '#2a273f'
  highlight_med  '#44415a'
  highlight_high '#56526e'
)

typeset -gA ZSH_HIGHLIGHT_STYLES

# Core syntax tokens
ZSH_HIGHLIGHT_STYLES[default]="fg=${_rose_pine_moon_palette[text]}"
ZSH_HIGHLIGHT_STYLES[unknown-token]="fg=${_rose_pine_moon_palette[love]}"
ZSH_HIGHLIGHT_STYLES[reserved-word]="fg=${_rose_pine_moon_palette[foam]}"
ZSH_HIGHLIGHT_STYLES[alias]="fg=${_rose_pine_moon_palette[foam]}"
ZSH_HIGHLIGHT_STYLES[suffix-alias]="fg=${_rose_pine_moon_palette[foam]}"
ZSH_HIGHLIGHT_STYLES[builtin]="fg=${_rose_pine_moon_palette[foam]}"
ZSH_HIGHLIGHT_STYLES[function]="fg=${_rose_pine_moon_palette[iris]}"
ZSH_HIGHLIGHT_STYLES[command]="fg=${_rose_pine_moon_palette[foam]}"
ZSH_HIGHLIGHT_STYLES[hashed-command]="fg=${_rose_pine_moon_palette[foam]}"
ZSH_HIGHLIGHT_STYLES[precommand]="fg=${_rose_pine_moon_palette[foam]},italic"
ZSH_HIGHLIGHT_STYLES[commandseparator]="fg=${_rose_pine_moon_palette[muted]}"

# Options and parameters
ZSH_HIGHLIGHT_STYLES[single-hyphen-option]="fg=${_rose_pine_moon_palette[gold]}"
ZSH_HIGHLIGHT_STYLES[double-hyphen-option]="fg=${_rose_pine_moon_palette[gold]}"
ZSH_HIGHLIGHT_STYLES[back-quoted-option]="fg=${_rose_pine_moon_palette[iris]}"
ZSH_HIGHLIGHT_STYLES[assign]="fg=${_rose_pine_moon_palette[rose]}"
ZSH_HIGHLIGHT_STYLES[named-fd]="fg=${_rose_pine_moon_palette[subtle]}"
ZSH_HIGHLIGHT_STYLES[dollar-parameter]="fg=${_rose_pine_moon_palette[foam]}"
ZSH_HIGHLIGHT_STYLES[dollar-parameter-brace]="fg=${_rose_pine_moon_palette[foam]}"
ZSH_HIGHLIGHT_STYLES[parameter]="fg=${_rose_pine_moon_palette[foam]}"
ZSH_HIGHLIGHT_STYLES[parameter-brace]="fg=${_rose_pine_moon_palette[muted]}"
ZSH_HIGHLIGHT_STYLES[parameter-expansion]="fg=${_rose_pine_moon_palette[foam]}"
ZSH_HIGHLIGHT_STYLES[parameter-flag]="fg=${_rose_pine_moon_palette[rose]}"
ZSH_HIGHLIGHT_STYLES[default-param]="fg=${_rose_pine_moon_palette[muted]}"

# Strings and quotes
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]="fg=${_rose_pine_moon_palette[gold]}"
ZSH_HIGHLIGHT_STYLES[single-quoted-argument-unclosed]="fg=${_rose_pine_moon_palette[love]}"
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]="fg=${_rose_pine_moon_palette[rose]}"
ZSH_HIGHLIGHT_STYLES[double-quoted-argument-unclosed]="fg=${_rose_pine_moon_palette[love]}"
ZSH_HIGHLIGHT_STYLES[dollar-double-quoted-argument]="fg=${_rose_pine_moon_palette[foam]}"
ZSH_HIGHLIGHT_STYLES[dollar-double-quoted-argument-unclosed]="fg=${_rose_pine_moon_palette[love]}"
ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]="fg=${_rose_pine_moon_palette[iris]}"
ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument-unclosed]="fg=${_rose_pine_moon_palette[love]}"
ZSH_HIGHLIGHT_STYLES[back-quoted-argument]="fg=${_rose_pine_moon_palette[iris]}"
ZSH_HIGHLIGHT_STYLES[back-quoted-argument-unclosed]="fg=${_rose_pine_moon_palette[love]}"
ZSH_HIGHLIGHT_STYLES[back-double-quoted-argument]="fg=${_rose_pine_moon_palette[foam]}"
ZSH_HIGHLIGHT_STYLES[back-double-quoted-argument-unclosed]="fg=${_rose_pine_moon_palette[love]}"
ZSH_HIGHLIGHT_STYLES[back-dollar-quoted-argument]="fg=${_rose_pine_moon_palette[iris]}"
ZSH_HIGHLIGHT_STYLES[rc-quote]="fg=${_rose_pine_moon_palette[pine]}"

# Paths, globs, and substitutions
ZSH_HIGHLIGHT_STYLES[globbing]="fg=${_rose_pine_moon_palette[foam]}"
ZSH_HIGHLIGHT_STYLES[history-expansion]="fg=${_rose_pine_moon_palette[iris]}"
ZSH_HIGHLIGHT_STYLES[back-reference]="fg=${_rose_pine_moon_palette[foam]}"
ZSH_HIGHLIGHT_STYLES[path]="fg=${_rose_pine_moon_palette[text]},underline"
ZSH_HIGHLIGHT_STYLES[path_prefix]="fg=${_rose_pine_moon_palette[text]},underline"
ZSH_HIGHLIGHT_STYLES[path_approx]="fg=${_rose_pine_moon_palette[text]}"
ZSH_HIGHLIGHT_STYLES[path_bracket]="fg=${_rose_pine_moon_palette[muted]}"
ZSH_HIGHLIGHT_STYLES[command-substitution]="fg=${_rose_pine_moon_palette[foam]}"
ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter]="fg=${_rose_pine_moon_palette[subtle]}"
ZSH_HIGHLIGHT_STYLES[command-substitution-unquoted]="fg=${_rose_pine_moon_palette[foam]}"
ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter-unquoted]="fg=${_rose_pine_moon_palette[subtle]}"
ZSH_HIGHLIGHT_STYLES[process-substitution]="fg=${_rose_pine_moon_palette[foam]}"
ZSH_HIGHLIGHT_STYLES[process-substitution-delimiter]="fg=${_rose_pine_moon_palette[subtle]}"

# Comments, math, and redirections
ZSH_HIGHLIGHT_STYLES[comment]="fg=${_rose_pine_moon_palette[muted]}"
ZSH_HIGHLIGHT_STYLES[c-style-comment]="fg=${_rose_pine_moon_palette[muted]}"
ZSH_HIGHLIGHT_STYLES[c-style-comment-unmatched]="fg=${_rose_pine_moon_palette[love]}"
ZSH_HIGHLIGHT_STYLES[redirection]="fg=${_rose_pine_moon_palette[gold]}"
ZSH_HIGHLIGHT_STYLES[math]="fg=${_rose_pine_moon_palette[gold]}"
ZSH_HIGHLIGHT_STYLES[if-then-else]="fg=${_rose_pine_moon_palette[gold]}"
ZSH_HIGHLIGHT_STYLES[for-loop]="fg=${_rose_pine_moon_palette[gold]}"
ZSH_HIGHLIGHT_STYLES[for-loop-variable]="fg=${_rose_pine_moon_palette[rose]}"

# Brackets and structure
ZSH_HIGHLIGHT_STYLES[bracket]="fg=${_rose_pine_moon_palette[subtle]}"
ZSH_HIGHLIGHT_STYLES[bracket-level-1]="fg=${_rose_pine_moon_palette[gold]}"
ZSH_HIGHLIGHT_STYLES[bracket-level-2]="fg=${_rose_pine_moon_palette[foam]}"
ZSH_HIGHLIGHT_STYLES[bracket-level-3]="fg=${_rose_pine_moon_palette[rose]}"
ZSH_HIGHLIGHT_STYLES[bracket-level-4]="fg=${_rose_pine_moon_palette[iris]}"
ZSH_HIGHLIGHT_STYLES[bracket-level-5]="fg=${_rose_pine_moon_palette[pine]}"
ZSH_HIGHLIGHT_STYLES[cursor-matchingbracket]="fg=${_rose_pine_moon_palette[rose]}"

# Miscellaneous
ZSH_HIGHLIGHT_STYLES[equals]="fg=${_rose_pine_moon_palette[rose]}"
ZSH_HIGHLIGHT_STYLES[whitespace]="fg=${_rose_pine_moon_palette[highlight_high]},bg=${_rose_pine_moon_palette[surface]}"

unset _rose_pine_moon_palette

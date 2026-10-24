# Themes

Ports of VS Code color themes to the terminal tools the `theme` light/dark toggle drives:
Ghostty, bat, delta, Helix, btop, starship, leaf, vivid (`LS_COLORS`), zsh-syntax-highlighting and fzf.

The input is a theme's **VS Code theme JSON**, since that's the one implementation almost every theme has.
A **Zed theme** works too, for themes that only exist for Zed (see [Zed themes](#zed-themes)).
Everything else is derived from it. Nothing in this directory is live until you install it (see
[Adopting a theme](#adopting-a-theme)).

```sh
node themes/build.mjs                        # rebuild every theme into <theme>/dist/
node themes/build.mjs --explain vitesse dark-soft   # show where each color came from
themes/try.sh vitesse                        # try it in a sandboxed Ghostty instance
themes/try.sh vitesse clean                  # undo what try.sh set up
```

## Layout

```
themes/
  build.mjs            generic builder: theme.json + VS Code JSON -> dist/
  try.sh               sandboxed trial of a built theme
  lib/
    vscode.mjs         JSONC parsing, `include`, TextMate scope resolution
    zed.mjs            Zed theme -> VS Code theme shape (key and syntax-capture translation)
    palette.mjs        VS Code theme -> named palette roles (the translation table)
    color.mjs          hex / alpha blending helpers
    targets/*.mjs      one file per tool; each starts with a comment explaining its color choices
  scripts/
    update-theme.sh    swaps one theme name for another in a config (generic update-rose-pine.sh)
    zsh-functions/theme  draft generic replacement for scripts/zsh-functions/theme
  <theme>/
    theme.json         manifest: variants, light/dark pairs, overrides, source, notes
    upstream/          the canonical VS Code theme JSON(s) + license, vendored unchanged
    dist/              generated: stow-shaped packages + snippets + pairs.sh. Don't edit.
```

`themes` is in `scripts/install.sh`'s `IGNORE_LIST`, so it never gets stowed as a package itself.

## Adding a theme

1. **Find the canonical VS Code theme.** Use the theme author's own extension, not a third-party port. Ports can
   be useful for comparison but aren't the source. You need the compiled theme JSON (the file the extension's
   `package.json` lists under `contributes.themes`):
   - In the repo, usually `themes/*.json`. If the repo generates themes from source (Vitesse does,
     from `scripts/colors.ts`), use the committed or released output, or build it.
   - If you have it installed: `~/.vscode/extensions/<publisher>.<name>-<version>/themes/`.
   - From a `.vsix`: it's a zip. The themes are under `extension/themes/`.

   JSONC (comments, trailing commas) and `"include"` (extending a base theme) are both handled. If the
   extension ships more than one file because of `include`, vendor all of them.
   `tokenColors` pointing at a `.tmTheme` file isn't supported. Convert it to JSON first.

   If the theme only exists for Zed, use its Zed extension's `themes/*.json` (see [Zed themes](#zed-themes)).

2. **Vendor it.** Create `themes/<slug>/upstream/`, copy in the JSON file(s) unchanged, and include
   the license. `<slug>` is lowercase with dashes. It prefixes every generated name (`<slug>-<variant>`).

3. **Write `themes/<slug>/theme.json`** (reference below). Declare every variant, and pair the variants
   into dark/light pairs for the toggle.

4. **Build and read the explanation:**

   ```sh
   node themes/build.mjs <slug>
   node themes/build.mjs --explain <slug> <variant>
   ```

   `--explain` lists every palette role with its color and the source that produced it
   (`ui:<key>`, `scope:<scope>`, `semantic:<token>`, a fallback `role:`/`mix:`, or an override).
   Look for:
   - **`<- placeholder` rows.** The theme didn't define that color, so a neutral default was used.
     This usually means the named accent hues (`red`, `green`, ...), when the theme leaves the
     terminal palette to VS Code's defaults. Override them with the theme's own hues.
   - **`mix:` rows.** These are derived surfaces (e.g. `bgActive`) for themes that define few workbench
     colors. They're usually fine, but check them in the sandbox.
   - **Roles that look wrong.** A scope can resolve to something the theme only meant as a fallback.
     Compare against how the theme actually looks in VS Code, then override.

5. **Override what's off** in `theme.json`: `"overrides"` applies to every variant, and a variant's own
   `"overrides"` wins over that. Values are `#hex` or `role:<other role>`. Roles that fall back to an
   overridden role follow it automatically (override `orange` and `warning`/`bracket3` follow). Rebuild.

6. **Try it:** `themes/try.sh <slug> [pair]`. Things worth checking, because they're where the translation
   makes judgment calls:
   - Ghostty: selection visibility, `ls` colors, a `git diff`.
   - Helix: popups and menus (`bgActive`), statusline mode colors, whitespace dots, diagnostics.
   - bat/delta: a diff with changed words (`minus/plus-emph`) and syntax highlighting.
   - btop, leaf (open a markdown file), starship prompt, fzf (`ctrl-r`), zsh highlighting.

   Record anything theme-specific you decided in `theme.json` `"notes"`.

7. **Clean up and commit:** `themes/try.sh <slug> clean`, then commit `upstream/`, `theme.json` and `dist/`.

To refresh a theme later, replace the files in `upstream/`, update `source.commit`, rebuild, and look at
`git diff themes/<slug>/dist`.

## theme.json

```jsonc
{
  "name": "Vitesse",                      // display name, used in comments and the sandbox banner
  "source": {                             // where upstream/ came from (informational)
    "url": "https://github.com/antfu/vscode-theme-vitesse",
    "commit": "2862595…",
    "files": "themes/vitesse-*.json"
  },
  "notes": ["…"],                         // decisions worth remembering next time
  "variants": {
    "dark-soft": {                        // id: lowercase + dashes; output stem is <slug>-<id>
      "name": "Vitesse Dark Soft",        // display name; also the Ghostty theme file name
      "file": "upstream/vitesse-dark-soft.json",
      "theme": "Vitesse Dark Soft",       // Zed files only: which theme of the family; defaults to "name"
      "mode": "dark",                     // optional; detected from the JSON's type/base or bg luminance
      "overrides": { "red": "#cb7676" }   // optional, this variant only
    }
  },
  "pairs": {                              // light/dark couples for the toggle and try.sh
    "soft": { "dark": "dark-soft", "light": "light-soft" }
  },
  "defaultPair": "soft",                  // optional; defaults to the first pair
  "overrides": {}                         // optional, all variants
}
```

Pair names are lowercase with underscores. `build` and `clean` are reserved. A theme with only one
flavor still needs a pair, e.g. `{ "default": { "dark": "dark", "light": "light" } }`.

## Zed themes

A variant's `file` can be a Zed theme family (`{ "themes": [{ "name", "appearance", "style" }] }`) instead of a
VS Code theme; it's detected from the JSON. `lib/zed.mjs` translates the chosen theme into a VS Code theme before
anything else sees it, so the palette table, `--explain` and every target work the same:

- `style` keys become the VS Code workbench keys the palette reads (`editor.active_line.background` ->
  `editor.lineHighlightBackground`, `terminal.ansi.red` -> `terminal.ansiRed`, `players[0].selection` ->
  `editor.selectionBackground`, `accents` -> `editorBracketHighlight.*`, ...). `--explain` shows the VS Code
  key names; the table at the top of `zed.mjs` maps them back.
- `syntax` captures become `tokenColors` rules for the TextMate scopes of the same construct (`keyword.import`
  -> `keyword.control.import`), so bat gets a real `.tmTheme` too.
- Translucent backgrounds (`background.appearance: blurred`) are made opaque: the editor and terminal
  backgrounds lose their alpha and everything else is flattened onto them.

Prefer a VS Code theme when one exists: Zed's model is coarser (one `keyword` for both `if` and `const`, no
markdown quote color), and Zed ports often recolor things. Running the Vitesse Zed ports through the adapter
reproduces 45–56 of the 72 roles of the VS Code original, and the rest are the ports' own choices.
Zed's bundled themes (and their derivatives) also tend to have odd terminal "bright" colors, dimmed toward the
background. Check the `ansi.bright*` rows. `ayu-glass` is the example.

## How colors are derived

`lib/palette.mjs` has the translation table: every palette role (`bg`, `selection`, `keyword`,
`ansi.red`, ...) with an ordered list of sources, and the first one the theme provides wins. In short:

- **UI roles** come from workbench `colors` (`editor.background`, `editor.lineHighlightBackground`,
  `editorLineNumber.foreground`, `diffEditor.*`, ...).
- **Accent hues and ANSI** come from `terminal.ansi*`, falling back to git/diagnostic colors.
- **Syntax roles** resolve a representative TextMate scope against `tokenColors`, the way VS Code does:
  the most specific dot-prefix match wins, and later rules break ties. Descendant selectors (`a b`)
  only apply in context, so they're ignored for role lookup. `semanticTokenColors` are used first
  where themes put class/interface/namespace colors there. Italic/bold from the matching rule is kept
  (Helix uses it).
- **bat's `.tmTheme`** isn't built from roles at all. It's the theme's `tokenColors` converted rule
  for rule, so code in bat/delta looks exactly as in VS Code.
- **Alpha:** terminals can't blend, so every translucent color is flattened onto `bg` (terminal colors
  onto `termBg`) before output.

Per-tool choices (which role btop's boxes use, how zsh tokens map to code constructs, delta's diff tints...)
are documented in the comment at the top of each `lib/targets/*.mjs`. They're the same for every theme.

## Outputs

`dist/` mirrors the stow packages, so the files can be copied into the real packages or stowed from here.

| Tool | File(s) in `dist/` | Goes to |
| --- | --- | --- |
| Ghostty | `ghostty/.config/ghostty/themes/<Variant Name>` | `~/.config/ghostty/themes/` |
| bat | `bat/.config/bat/themes/<stem>.tmTheme` | `~/.config/bat/themes/`, then `bat cache --build` |
| delta | `snippets/delta.gitconfig` | `[include]` from `.gitconfig`, set `[delta] features` |
| Helix | `helix/.config/helix/themes/<stem_us>.toml` | `~/.config/helix/themes/` |
| btop | `btop/.config/btop/themes/<stem>.theme` | `~/.config/btop/themes/` |
| starship | `snippets/starship-palettes.toml` | append to `starship.toml`, set `palette` |
| leaf | `snippets/leaf-themes.toml` | append to `leaf/config.toml`, set `theme` |
| vivid | `vivid/.config/vivid/themes/<stem>.yml` | `~/.config/vivid/themes/` |
| zsh-syntax-highlighting, fzf | `zsh/.zsh/<stem_us>-{zsh-syntax-highlighting,fzf}.zsh` | `~/.zsh/` |
| (shell) | `pairs.sh` | read by `try.sh` and the `theme` function |

`<stem>` is `<slug>-<variant>` (e.g. `vitesse-dark-soft`); `<stem_us>` is the same with underscores
(Helix theme names and the zsh files use it).

## Trying a theme

`themes/try.sh <slug> [pair]` opens a separate Ghostty instance. Its shell loads your normal `~/.zshrc`, then
layers the theme on top. Your real configs are only read: the sandbox uses copies in `~/.cache/theme-try/<slug>/`,
with only the theme lines changed. It points each tool at its copy with `STARSHIP_CONFIG`, `BAT_THEME`,
`GIT_PAGER="delta --config …"`, `hx`/`leaf` aliases with their own `XDG_CONFIG_HOME`, and `btop -c`.
Quit that instance to go back.

- It follows macOS appearance at startup. Run `theme-try-mode light|dark` after changing it.
- `themes/try.sh <slug> build [pair]` builds the sandbox without launching. Enter it from any terminal
  with `ZDOTDIR=~/.cache/theme-try/<slug>/zdot zsh` (you get everything except Ghostty's own colors).
- **One change outside the sandbox:** delta reads syntax themes only from bat's default cache, so the
  `.tmTheme` files are symlinked into `~/.config/bat/themes` and the cache is rebuilt. That only adds
  themes. `clean` removes them.
- The copies need the lines being swapped to exist in your real configs: `palette = ` (starship),
  `theme = ` (Helix, leaf), `color_theme = ` (btop).

## Adopting a theme

1. **Install the standalone files** by copying into the real packages (then restow as usual):

   ```sh
   cd ~/dotfiles
   for pkg in ghostty bat helix btop vivid zsh; do cp -R themes/<slug>/dist/$pkg/. $pkg/; stow --no-folding $pkg; done
   bat cache --build
   ```

2. **Point the configs at it**, using the stems from `dist/pairs.sh`:
   - Ghostty: `theme = dark:<Dark Name>,light:<Light Name>`
   - bat: `--theme="<stem>"`
   - Helix: `theme = "<stem_us>"`
   - btop: `color_theme = "/Users/fjorn/.config/btop/themes/<stem>.theme"`
   - git: `[include] path = "~/dotfiles/themes/<slug>/dist/snippets/delta.gitconfig"` and
     `[delta] features = <stem>`
   - starship: append `snippets/starship-palettes.toml`, set `palette = "<stem>"`. The palettes redefine
     `red`/`green`/... so the prompt's `bold green`-style module styles use the theme's colors.
   - leaf: append `snippets/leaf-themes.toml`, set `theme = "<stem>"`. leaf can only use its built-in
     syntect themes for code blocks, so just its UI and markdown colors come from the theme.
3. **Toggle:** replace `scripts/zsh-functions/theme` with `themes/scripts/zsh-functions/theme`. It takes
   `THEME_SLUG` / `THEME_PAIR` env vars, flips each config between the pair's dark and light stems
   with `update-theme.sh`, and loads the matching `LS_COLORS`, fzf and zsh-highlighting files.
   `zsh/.zshrc` picks the startup mode with `grep -q 'palette = "rose-pine-dawn"'`, so change it to
   match the new light stem. The Rosé Pine `TERM16M_*` variables have no equivalent (nothing reads them).
4. **Zed** isn't generated here. Use the theme's Zed extension (for a Zed-sourced theme, that's the source).

## Adding a tool

Create `lib/targets/<tool>.mjs` exporting `{ name, files(p, ctx) }` for one file per variant and/or
`{ combined(variants, ctx) }` for one snippet covering all variants. Both return `[{ path, content }]`,
with paths relative to `dist/`. Register it in `TARGETS` in `build.mjs`. `p` is the palette (all roles are
listed in `lib/palette.mjs`, and `--explain` prints them). `ctx` has `stem`, `stemUs`, `variant`, `theme`,
the raw `vscode` theme, and `header(commentChar)` for the "generated" line. Start the file with a
comment explaining its color choices, and if the tool needs installing or trying, add it to the table above
and to `try.sh`.

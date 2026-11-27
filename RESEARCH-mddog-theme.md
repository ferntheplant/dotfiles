# mddog: Rosé Pine Moon

## Recommendation

Use a custom `rose-pine-moon.css` theme. The installed `mdd` reports `1.2.0`, which supports custom themes. No upgrade is necessary.
Neither [v1.2.0](https://github.com/qu8n/mddog/blob/v1.2.0/src/theme.rs#L7-L15) nor [v1.5.0](https://github.com/qu8n/mddog/blob/v1.5.0/src/theme.rs#L7-L15) includes Rosé Pine Moon.
Both versions include only `github-light`, `github-dark`, `obsidian-light`, and `obsidian-dark`.
[GitHub marks v1.5.0 as the latest release](https://github.com/qu8n/mddog/releases/latest) as of 2026-11-26.

Put these two files in `$XDG_CONFIG_HOME/mddog/`, or in `~/.config/mddog/` if `XDG_CONFIG_HOME` is unset or empty.
Set the top-level `theme` key in `config.toml`:

```toml
theme = "rose-pine-moon.css"
```

This selects Moon in both desktop appearance modes. Use `theme = "light:github-light,dark:rose-pine-moon.css"` if Moon must apply only in dark mode.
Relative theme paths start at the config directory. Absolute paths and `~/` also work. Restart `mdd` after a change.
See the [v1.2.0 configuration docs](https://github.com/qu8n/mddog/blob/v1.2.0/website/content/docs/config.mdx#L6-L56), [config directory lookup](https://github.com/qu8n/mddog/blob/v1.2.0/src/config.rs#L257-L274), and [path resolution](https://github.com/qu8n/mddog/blob/v1.2.0/src/theme.rs#L221-L232).

## Theme format and scope

The `.css` file accepts only `:root` declarations with mddog tokens, which are named settings.
Colors must be literal `#rgb` or `#rrggbb` values. The parser rejects `var()`, alpha, arbitrary CSS rules, and unknown tokens.
Set `color-scheme: dark` or inherit it through `--mddog-base: github-dark`. Both can appear if they agree.
Omitted tokens inherit from the base, or from GitHub's theme for the same color scheme if there is no base.
See the [v1.2.0 theme docs](https://github.com/qu8n/mddog/blob/v1.2.0/website/content/docs/themes.mdx#L25-L66) and [parser tests](https://github.com/qu8n/mddog/blob/v1.2.0/src/theme.rs#L444-L470).

The theme controls the Markdown page and the terminal interface, including the file list, status bar, and table of contents.
The [v1.2.0 token list](https://github.com/qu8n/mddog/blob/v1.2.0/website/content/docs/themes.mdx#L68-L148) also covers code colors, fonts, sizes, weights, line heights, and GitHub or Obsidian layout.
Keep the GitHub layout and default fonts if the goal is only to change colors.
Use the [v1.2.0 GitHub Dark file](https://github.com/qu8n/mddog/blob/v1.2.0/assets/themes/github-dark.css) as a complete list of accepted color keys.

### Example palette

This is a starter theme, not a complete recolor. The hex values come from the [official Rosé Pine Moon palette](https://github.com/rose-pine/palette/blob/main/dist/css/rose-pine.css#L18-L32).
The [Rosé Pine role guide](https://github.com/rose-pine/palette#roles) recommends Iris for links, Gold for strings, and Pine for functions.
Copy the literal values into mddog tokens. Do not import the Rosé Pine stylesheet.

```css
:root {
  --mddog-base: github-dark;
  --mddog-bg: #232136;
  --mddog-fg: #e0def4;
  --mddog-fg-muted: #908caa;
  --mddog-fg-bright: #e0def4;
  --mddog-selection-bg: #44415a;
  --mddog-bar-bg: #2a273f;
  --mddog-border: #56526e;
  --mddog-skeleton: #393552;

  --mddog-text: #e0def4;
  --mddog-text-muted: #908caa;
  --mddog-heading: #e0def4;
  --mddog-link: #c4a7e7;
  --mddog-code-bg: #393552;
  --mddog-pre-bg: #2a273f;
  --mddog-alt-bg: #2a283e;
  --mddog-rule: #56526e;
  --mddog-text-selection: #44415a;

  --mddog-pl-string: #f6c177;
  --mddog-pl-entity: #3e8fb0;
}
```

To remove the remaining GitHub colors, review the other code tokens, alerts, search highlights, and diff backgrounds.
Check the contrast of search text against each search background. Each has its own token.

The 1.2.0 and 1.5.0 binaries accept this example in a temporary config directory. Both reject `var()` in a color token.
This check confirms that the binaries accept the theme file. It does not check the colors on screen.

## Version differences

- v1.2.0 loads the theme at startup. The [`T` theme picker arrived in v1.3.0](https://github.com/qu8n/mddog/releases/tag/v1.3.0).
- In v1.5.0, `T` opens the picker. `Space` previews the theme. `Enter` writes the `theme` key to `config.toml`. The writer follows a symbolic link to its target. See the [picker docs](https://mddog.pages.dev/docs/themes#previewing-themes) and [save code](https://github.com/qu8n/mddog/blob/v1.5.0/src/config.rs#L480-L525).
- v1.5.0 adds five `--mddog-hint-*` tokens for keyboard link labels. Leave them out of a shared theme. v1.5.0 will inherit them and v1.2.0 will reject them. Compare the [v1.2.0 token list](https://github.com/qu8n/mddog/blob/v1.2.0/src/theme.rs#L99-L121) with the [v1.5.0 token list](https://github.com/qu8n/mddog/blob/v1.5.0/src/theme.rs#L99-L122).

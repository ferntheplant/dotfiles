// btop theme — https://github.com/aristocratos/btop#themes
//
// VS Code has nothing like btop, so these are judgment calls kept consistent across themes:
//   boxes: cpu = green, mem = orange, net = blue, proc = magenta
//   gradients run green -> yellow -> red (cool to hot) for cpu, temp and per-process usage
//   selected row = editor selection + primary, like a focused list item in VS Code

export default {
  name: 'btop',
  files(p, { stem, header }) {
    const t = {
      main_bg: p.bg,
      main_fg: p.fg,
      title: p.fgActive,
      hi_fg: p.primary,
      selected_bg: p.selection,
      selected_fg: p.fg,
      inactive_fg: p.muted,
      graph_text: p.fgSecondary,
      meter_bg: p.lineHighlight,
      proc_misc: p.cyan,
      cpu_box: p.green,
      mem_box: p.orange,
      net_box: p.blue,
      proc_box: p.magenta,
      div_line: p.muted,
      temp_start: p.green, temp_mid: p.yellow, temp_end: p.red,
      cpu_start: p.green, cpu_mid: p.yellow, cpu_end: p.red,
      free_start: p.cyan, free_mid: p.cyan, free_end: p.cyan,
      cached_start: p.blue, cached_mid: p.blue, cached_end: p.blue,
      available_start: p.green, available_mid: p.green, available_end: p.green,
      used_start: p.orange, used_mid: p.orange, used_end: p.red,
      download_start: p.blue, download_mid: p.cyan, download_end: p.cyan,
      upload_start: p.magenta, upload_mid: p.red, upload_end: p.red,
      process_start: p.green, process_mid: p.yellow, process_end: p.red,
    }
    return [{
      path: `btop/.config/btop/themes/${stem}.theme`,
      content: `${header('#')}\n\n${Object.entries(t).map(([k, v]) => `theme[${k}]="${v}"`).join('\n')}\n`,
    }]
  },
}

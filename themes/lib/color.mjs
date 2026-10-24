// Hex color helpers. Terminal tools can't render alpha, so translucent VS Code colors
// (#rgba / #rrggbbaa) are flattened onto whatever they sit on before being written out.

export function parseHex(hex) {
  let h = String(hex).trim().replace(/^#/, '')
  if (h.length === 3 || h.length === 4)
    h = [...h].map(c => c + c).join('')
  if (!/^[0-9a-f]{6}([0-9a-f]{2})?$/i.test(h))
    throw new Error(`Not a hex color: ${hex}`)
  const n = i => Number.parseInt(h.slice(i, i + 2), 16)
  return { r: n(0), g: n(2), b: n(4), a: h.length === 8 ? n(6) / 255 : 1 }
}

export const isHex = v => typeof v === 'string' && /^#([0-9a-f]{3,4}|[0-9a-f]{6}|[0-9a-f]{8})$/i.test(v.trim())

export const toHex = ({ r, g, b }) => `#${[r, g, b].map(c => Math.round(c).toString(16).padStart(2, '0')).join('')}`

export const alpha = hex => parseHex(hex).a

// Flatten a (possibly translucent) color onto `under` (which must be opaque).
export function blend(hex, under) {
  const c = parseHex(hex)
  const u = parseHex(under)
  return toHex({
    r: c.r * c.a + u.r * (1 - c.a),
    g: c.g * c.a + u.g * (1 - c.a),
    b: c.b * c.a + u.b * (1 - c.a),
  })
}

// `amount` (0..1) of `hex` over `under`, e.g. tinted diff backgrounds.
export function mix(hex, under, amount) {
  const solid = blend(hex, under)
  return blend(solid + Math.round(amount * 255).toString(16).padStart(2, '0'), under)
}

// WCAG relative luminance; used to tell dark themes from light ones.
export function luminance(hex) {
  const lin = c => (c /= 255) <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4
  const { r, g, b } = parseHex(hex)
  return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
}

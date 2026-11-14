-- Pane navigation, carried over from the Ghostty config (keybind = alt+h=goto_split:left, ...)
rex.bind("alt+h", "pane.focus.left")
rex.bind("alt+j", "pane.focus.down")
rex.bind("alt+k", "pane.focus.up")
rex.bind("alt+l", "pane.focus.right")

-- Floating panes, for a quick command that should not resize the splits.
-- A minimized float stays in its tab, and its program keeps running.
rex.bind("cmd+shift+f", "pane.new_floating")

-- The window of a block, the layer that holds it, and the block itself.
local function find_block(view, block_id)
  for _, w in ipairs(view.windows or {}) do
    for _, layer in ipairs(w.layers or {}) do
      for _, b in ipairs(layer.blocks or {}) do
        if b.block_id == block_id then return w, layer, b end
      end
    end
  end
end

rex.action{
  name = "float_toggle",
  title = "Minimize or Restore Floating Pane",
  description = "Minimize the focused float. Outside a float, bring back the newest minimized float in this tab.",
  keywords = "float floating minimize restore toggle scratch",
  run = function(ctx)
    local view, err = rex.session.view{}
    if not view then error(err, 0) end
    local window, layer = find_block(view, ctx.block_id)
    if not window then return end
    if layer.kind == "floating" and layer.state ~= "minimized" then
      local _, e = rex.session.set_layer_state{ layer_id = layer.layer_id, state = "minimized" }
      if e then error(e, 0) end
      return
    end
    -- Later layers sit in front, so the last minimized one is the newest.
    local newest
    for _, l in ipairs(window.layers or {}) do
      if l.kind == "floating" and l.state == "minimized" then newest = l end
    end
    if not newest then return end
    local _, e = rex.session.set_layer_state{ layer_id = newest.layer_id, state = "normal", focus = true }
    if e then error(e, 0) end
  end,
}
rex.bind("cmd+shift+m", "float_toggle")

-- A one-screen form in a float: host, session, directory, and name, filled from
-- the focused pane. It opens a new tab or session. Use it in place of a split for unrelated work.
local TERMINAL = "com.superlogical.terminal"
local FORM_LABEL = "new-workflow"

-- The working directory of a pane's foreground program, or nil.
local function pane_cwd(block_id)
  local p = rex.block.call(TERMINAL, "process", { block_id = block_id })
  local cwd = p and ((p.foreground or {}).cwd or (p.child or {}).cwd)
  if cwd then return cwd end
  local pwd = rex.block.call(TERMINAL, "pwd", { block_id = block_id })
  return pwd and pwd.path or nil
end

-- The rect of a block in a layout tree, as {x, y, w, h} fractions of its window.
local function find_rect(node, block_id)
  if type(node) ~= "table" then return nil end
  if node.block_id == block_id and node.rect then return node.rect end
  for _, child in pairs(node) do
    local r = type(child) == "table" and find_rect(child, block_id)
    if r then return r end
  end
end

-- Bounds for a float of about cols x rows cells, centered in the focused block's window.
local function float_bounds(view, block_id, cols, rows)
  local window = find_block(view, block_id)
  local size = rex.block.call(TERMINAL, "size", { block_id = block_id })
  local rect = window and find_rect(window.layers, block_id)
  if not (size and rect and rect[3] > 0 and rect[4] > 0) then return { 0.25, 0.2, 0.5, 0.5 } end
  local w = math.min(0.9, cols / (size.columns / rect[3]))
  local h = math.min(0.9, rows / (size.rows / rect[4]))
  return { (1 - w) / 2, (1 - h) / 3, w, h }
end

rex.action{
  name = "new_workflow",
  title = "New Tab or Session…",
  description = "Pick a host, a session, and a directory, then open a new tab or session there.",
  keywords = "new workflow tab session host directory project open zoxide",
  run = function(ctx)
    local view = rex.session.view{}
    local window = view and (find_block(view, ctx.block_id))
    local _, err = rex.session.new_layer{
      window_id = window and window.window_id or nil,
      bounds = window and float_bounds(view, ctx.block_id, 84, 22) or { 0.25, 0.2, 0.5, 0.5 },
      focus = true,
      layout = rex.layout.block{
        flavor = TERMINAL .. ".shell",
        label = FORM_LABEL,
        options = {
          command = {
            os.getenv("HOME") .. "/.config/rex/new-workflow.py",
            "--client", ctx.client_id or "",
            "--session", ctx.session_id or "",
            "--cwd", (ctx.block_id and pane_cwd(ctx.block_id)) or "",
          },
        },
      },
    }
    if err then error(err, 0) end
  end,
}
rex.bind("cmd+shift+o", "new_workflow")

-- Cmd+Enter submits the form. Anywhere else it keeps Rex's default, Split Pane Best Fit:
-- a key bound to a function no longer reaches the default, so do that split here.
rex.bind("cmd+enter", function(ctx)
  if not ctx.block_id then return false end
  local view = rex.session.view{}
  if not view then return false end
  local _, _, block = find_block(view, ctx.block_id)
  if not block then return false end
  if block.label == FORM_LABEL then
    rex.block.call(TERMINAL, "write", { block_id = ctx.block_id, data = "\19" }) -- Ctrl+S
    return true
  end
  local size = rex.block.call(TERMINAL, "size", { block_id = ctx.block_id }) or {}
  local wide = (size.columns or 0) * (size.cell_width_px or 1) >= (size.rows or 0) * (size.cell_height_px or 1)
  rex.session.new_split{
    anchor_id = ctx.block_id,
    direction = wide and "horizontal" or "vertical",
    side = "after",
    focus = true,
    layout = rex.layout.block{ flavor = TERMINAL .. ".shell", options = { cwd = pane_cwd(ctx.block_id) } },
  }
  return true
end)

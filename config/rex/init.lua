-- Rex config — tmux/herdr muscle memory on a ctrl+b prefix.
-- Docs: https://www.superlogical.com/rex/docs/customize/key-sequences
-- Apply:   rex config reload   (Rex doesn't watch this file)
-- Inspect: rex config check / rex keymap / rex -C donald-mbp actions
--
-- Mapping: tmux session / herdr workspace -> Rex session,
--          tmux window / herdr tab        -> Rex tab, pane -> pane.

local P = "ctrl+b>"
local function bind(keys, action, args) rex.bind(P .. keys, action, args) end

-- ctrl+b now starts a sequence, so it never reaches the terminal alone.
-- Press it twice to send one (e.g. to a nested tmux, or readline's back-char).
bind("ctrl+b", "pane.send_key", { key = "ctrl+b" })

-- ── Tabs (tmux windows) ──────────────────────────────────────────────────
bind("c", "client.tab.new")
bind("n", "client.tab.next")
bind("p", "client.tab.previous")
bind(",", "client.tab.rename")
bind("shift+7", "client.tab.close") -- & kill-window
bind("shift+,", "client.tab.move.backward") -- < (pain-control)
bind("shift+.", "client.tab.move.forward") -- >
bind("shift+1", "pane.move_to_new_tab") -- ! break-pane
for i = 1, 9 do -- baseIndex = 1
  bind(tostring(i), "client.tab.goto", { index = i })
end

-- ── Splits (pain-control | - plus tmux % " and herdr v) ──────────────────
bind("shift+\\", "pane.split", { direction = "right" }) -- |
bind("-", "pane.split", { direction = "down" })
bind("v", "pane.split", { direction = "right" }) -- herdr
bind("shift+5", "pane.split", { direction = "right" }) -- %
bind("shift+'", "pane.split", { direction = "down" }) -- "

-- ── Panes ────────────────────────────────────────────────────────────────
for key, dir in pairs({ h = "left", j = "down", k = "up", l = "right" }) do
  bind(key, "pane.focus", { direction = dir }) -- pain-control
  bind("ctrl+" .. key, "pane.focus", { direction = dir })
  bind("shift+" .. key, "pane.resize", { direction = dir, amount = 5 })
end
bind("o", "pane.focus_next")
bind("z", "pane.zoom")
bind("x", "pane.close") -- tmux.nix: bind x kill-pane
bind("=", "pane.balance") -- herdr/tmux select-layout even
bind("f", "pane.float")

-- ── Sessions (tmux sessions / herdr workspaces) ──────────────────────────
-- prefix T was the sesh picker in tmux and herdr; Rex's own switcher takes it.
bind("shift+t", "session.switch")
bind("s", "session.switch")
bind("shift+4", "session.rename") -- $
bind("shift+9", "session.previous") -- (
bind("shift+0", "session.next") -- )

-- ── Misc ─────────────────────────────────────────────────────────────────
bind("r", "client.config.reload") -- tmux reload
bind("shift+r", "client.config.reload") -- herdr reload
bind("[", "client.find.open") -- copy-mode search; scrollback is native
bind("ctrl+y", "client.sidebar.activity.toggle") -- herdr agent picker -> Activity
bind("shift+;", "client.palette.toggle") -- : command prompt

-- ── Lazygit popup (herdr prefix+alt+g / tmux display-popup) ──────────────
-- Floating layer in the focused pane's directory; closes when lazygit exits.
local TERMINAL = "com.superlogical.terminal"

local function focused_dir(ctx)
  local r = rex.block.call(TERMINAL, "pwd", { block_id = ctx.block_id })
  local pwd = r and r.pwd
  if not pwd then return nil end
  -- OSC 7 reports file://host/path; take the path.
  return pwd:match("^file://[^/]*(/.*)$") or pwd
end

rex.action({
  name = "lazygit_popup",
  title = "Lazygit Popup",
  category = "Tools",
  run = function(ctx)
    local _, err = rex.session.new_layer({
      bounds = { 0.05, 0.05, 0.9, 0.9 },
      focus = true,
      layout = rex.layout.block({
        flavor = TERMINAL .. ".shell",
        options = { command = { "lazygit" }, cwd = focused_dir(ctx) },
      }),
    })
    if err ~= nil then error(err, 0) end
  end,
})
bind("alt+g", "lazygit_popup")

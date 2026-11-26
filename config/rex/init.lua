-- Rex config. Key bindings are Rex's defaults: the tmux/herdr ctrl+b prefix
-- map was removed (INV-0004) to try the built-in cmd keys and the quick
-- switcher (cmd+p). Add bindings back here only where a default is missing.
-- Docs: https://www.superlogical.com/rex/docs/customize/key-sequences
-- Apply:   rex config reload   (Rex doesn't watch this file)
-- Inspect: rex config check / rex keymap / rex -C donald-mbp actions

-- ── Session restore: resume rules (INV-0004) ─────────────────────────────
-- After a server restart Rex can bring Claude Code back in its pane. Only
-- resume it under ~/code. rex.set is newer than 0.1.0-preview.21, where
-- calling it is a load error, so guard it until every machine has updated.
-- Docs: https://www.superlogical.com/rex/docs/customize/resume-rules
if rex.set then
  rex.set("resume.trust.claude.dir", "~/code")
end

-- ── Lazygit popup ────────────────────────────────────────────────────────
-- Floating layer in the focused pane's directory; closes when lazygit exits.
local TERMINAL = "com.superlogical.terminal"

local function focused_dir(ctx)
  -- Ask where the foreground process really is. "pwd" only knows what a
  -- program reported with OSC 7, and our zsh doesn't report it.
  local p = rex.block.call(TERMINAL, "process", { block_id = ctx.block_id })
  local cwd = p and p.foreground and p.foreground.cwd
  if cwd then return cwd end
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
rex.bind("ctrl+cmd+g", "lazygit_popup") -- no Rex default uses this chord

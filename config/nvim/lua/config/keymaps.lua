-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local keymap = vim.keymap.set

-- Buffer tab cycle
keymap("n", "<S-Tab>", "<cmd>bprevious<cr>", { desc = "Prev Buffer" })
keymap("n", "<Tab>", "<cmd>bnext<cr>", { desc = "Next Buffer" })

-- buffer remove
keymap("n", "<S-q>", function()
  Snacks.bufdelete()
end, { desc = "Delete Buffer" })

-- fff.nvim overrides for LazyVim default pickers
keymap("n", "<leader>ff", function() require("fff").find_files() end, { desc = "Find Files (fff)" })
keymap("n", "<leader><space>", function() require("fff").find_files() end, { desc = "Find Files (fff)" })
keymap("n", "<leader>/", function() require("fff").live_grep() end, { desc = "Grep (fff)" })
keymap("n", "<leader>fg", function() require("fff").live_grep() end, { desc = "Live Grep (fff)" })
keymap("n", "<leader>fw", function() require("fff").live_grep({ query = vim.fn.expand("<cword>") }) end, { desc = "Search word (fff)" })

-- docz HTML preview: export the current docz document as a standalone page and
-- open it — in a terminal-browser split inside Rex, else the system browser.
-- Not live: press again after saving to re-export.
local docz_html_out = vim.fn.tempname()
keymap("n", "<leader>mh", function()
  local file = vim.api.nvim_buf_get_name(0)
  local root = vim.fs.root(0, ".docz.yaml")
  if file == "" or not root then
    vim.notify("[docz] not a file in a docz repository", vim.log.levels.WARN)
    return
  end
  if vim.fn.executable("docz") ~= 1 then
    vim.notify("[docz] docz is not on PATH", vim.log.levels.ERROR)
    return
  end
  vim.system(
    { "docz", "export", "html", file, "--out", docz_html_out, "--format", "json" },
    { cwd = root, text = true },
    vim.schedule_wrap(function(res)
      local ok, report = pcall(vim.json.decode, res.stdout or "")
      local page = ok and report.pages and report.pages[1]
      if res.code ~= 0 or not page then
        vim.notify("[docz] export failed: " .. vim.trim(res.stderr or ""), vim.log.levels.ERROR)
        return
      end
      local html = docz_html_out .. "/" .. page.path
      if vim.env.TERM_PROGRAM == "rex" and vim.fn.executable("terminal-browser-split") == 1 then
        vim.fn.jobstart({ "terminal-browser-split", html }, { detach = true })
      else
        vim.ui.open(html)
      end
    end)
  )
end, { desc = "docz HTML preview" })

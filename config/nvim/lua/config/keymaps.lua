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

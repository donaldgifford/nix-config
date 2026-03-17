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

return {
  -- Disable the default markdown previewer
  { "iamcco/markdown-preview.nvim", enabled = false },
  -- Enable mdp
  {
    "donaldgifford/mdp",
    -- branch = "feat/log-file-docs", -- Development branch
    keys = {
      { "<leader>cp", "<cmd>MdpToggle<cr>", desc = "Toggle markdown preview" },
      { "<leader>mo", "<cmd>MdpOpen<cr>", desc = "Open preview in browser" },
    },
    opts = {
      port = 0, -- 0 = auto-assign
      browser = true, -- Open browser on start
      theme = "dark", -- "auto", "light", or "dark"
      scroll_sync = true, -- Sync preview scroll with cursor
      idle_timeout_secs = 30, -- Shut down after N seconds with no open tab (0 = disabled)
      log_file = vim.fn.stdpath("log") .. "/mdp.log", -- "" to disable
    },
  },
}

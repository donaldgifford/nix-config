return {
	{
		"folke/tokyonight.nvim",
		lazy = false,
		priority = 1000,
		opts = { style = "night", transparent = true },
	},
	-- { "rose-pine/neovim", name = "rose-pine" },
	-- {
	-- 	"tiagovla/tokyodark.nvim",
	-- 	opts = {
	-- 		-- custom options here
	-- 		transparent_background = true, -- set background to transparent
	-- 	},
	-- 	config = function(_, opts)
	-- 		require("tokyodark").setup(opts) -- calling setup is optional
	-- 		vim.cmd([[colorscheme tokyodark]])
	-- 	end,
	-- },
	-- Configure LazyVim to load gruvbox
	{
		"LazyVim/LazyVim",
		opts = {
			colorscheme = "tokyonight",
		},
	},
}

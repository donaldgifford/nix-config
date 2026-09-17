-- Colorscheme follows the active theme set by `theme` (config/themes/
-- theme-switch.sh): ~/.config/themes/current/nvim holds the colorscheme name.
-- Falls back to tokyonight when no theme has been selected.
local function current_colorscheme()
	local f = io.open(vim.fn.expand("~/.config/themes/current/nvim"), "r")
	if f then
		local name = f:read("*l")
		f:close()
		if name and #name > 0 then
			return name
		end
	end
	return "tokyonight"
end

return {
	{
		"folke/tokyonight.nvim",
		lazy = false,
		priority = 1000,
		opts = { style = "night", transparent = true },
	},
	-- Warm Burnout (https://github.com/felipefdl/warm-burnout) — monorepo;
	-- the nvim plugin lives in the nvim/ subdirectory. The rtp append must
	-- happen in `init` (runs before plugins load) so the colors/ dir is
	-- visible when LazyVim applies the colorscheme — in `config` it's too
	-- late and LazyVim throws E185.
	{
		"felipefdl/warm-burnout",
		lazy = false,
		priority = 1000,
		init = function(plugin)
			vim.opt.rtp:append(plugin.dir .. "/nvim")
		end,
	},
	{
		"LazyVim/LazyVim",
		opts = {
			colorscheme = current_colorscheme(),
		},
	},
}

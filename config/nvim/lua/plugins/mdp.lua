-- Inside Rex the preview goes to a terminal-browser split instead of the
-- system browser. The mdp server honours $BROWSER on start, but :MdpOpen calls
-- `open` itself and :MdpToggle stops a running server, so neither can bring
-- back a preview pane that was closed. The wrapper records the URL and the
-- keymaps below reopen it.
local wrapper = "terminal-browser-split" -- on PATH from home/common/rex.nix
local mdp_browser = vim.fn.stdpath("config") .. "/bin/mdp-browser" -- records the URL first
local url_file = vim.fn.tempname()

local function in_rex()
	return vim.env.TERM_PROGRAM == "rex" and vim.fn.executable(wrapper) == 1
end

local function running_url()
	if not (in_rex() and require("mdp").is_running()) then
		return nil
	end
	local f = io.open(url_file)
	if not f then
		return nil
	end
	local url = f:read("l")
	f:close()
	return url
end

-- Start the preview, or reopen its pane if the server is already running.
-- In Rex this never stops the server: use :MdpStop, or the idle timeout.
local function preview()
	local url = running_url()
	if url then
		vim.fn.jobstart({ wrapper, url }, { detach = true })
	else
		vim.cmd("MdpToggle")
	end
end

local function open()
	local url = running_url()
	if url then
		vim.fn.jobstart({ wrapper, url }, { detach = true })
	else
		vim.cmd("MdpOpen")
	end
end

return {
	-- Disable the default markdown previewer
	{ "iamcco/markdown-preview.nvim", enabled = false },
	-- Enable mdp
	{
		"donaldgifford/mdp",
		-- branch = "feat/impl-0006", -- Development branch
		init = function()
			if in_rex() then
				-- For this Neovim only, not the whole shell.
				vim.env.BROWSER = mdp_browser
				vim.env.MDP_URL_FILE = url_file
			end
		end,
		keys = {
			-- <leader>mp also comes from the plugin's own lazy.lua (:MdpPreview),
			-- which reopens through `open`; override it so both keys match.
			{ "<leader>mp", preview, ft = "markdown", desc = "Markdown preview" },
			{ "<leader>cp", preview, desc = "Markdown preview" },
			{ "<leader>mo", open, desc = "Open preview in browser" },
		},
		opts = {
			port = 0, -- 0 = auto-assign
			browser = true, -- Open browser on start
			theme = "tokyo-night", -- "auto", "light", or "dark"
			scroll_sync = true, -- Sync preview scroll with cursor
			idle_timeout_secs = 30, -- Shut down after N seconds with no open tab (0 = disabled)
			log_file = vim.fn.stdpath("log") .. "/mdp.log", -- "" to disable
		},
	},
}

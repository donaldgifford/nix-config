-- SpiceDB schema LSP for .zed files (filetype `authzed` is built into
-- nvim core; treesitter grammar installed separately).
-- Binary comes from homebrew: authzed/tap/spicedb (declared in darwin.nix).
return {
	{
		"nvim-treesitter/nvim-treesitter",
		-- upstream grammar can't parse `use expiration` (required for
		-- expiring relations) — our fork adds it. PR'd upstream; drop the
		-- override once merged and nvim-treesitter bumps its pin.
		opts = function(_, opts)
			local function use_fork()
				local parsers = require("nvim-treesitter.parsers")
				parsers.authzed = vim.tbl_deep_extend("force", parsers.authzed or {}, {
					install_info = {
						url = "https://github.com/donaldgifford/tree-sitter-authzed",
						revision = "89208bd21fe9ff2d0249c01cbb174606d1851e09", -- feat/use-statement
					},
				})
			end
			use_fork()
			-- install/update re-requires parsers.lua, wiping runtime overrides;
			-- the User TSUpdate autocmd is nvim-treesitter's hook to re-apply them
			vim.api.nvim_create_autocmd("User", { pattern = "TSUpdate", callback = use_fork })
			opts.ensure_installed = opts.ensure_installed or {}
			table.insert(opts.ensure_installed, "authzed")
		end,
		-- treesitter main branch has no global highlight toggle — start it
		-- explicitly for authzed buffers
		init = function()
			vim.api.nvim_create_autocmd("FileType", {
				pattern = "authzed",
				callback = function()
					pcall(vim.treesitter.start)
				end,
			})
		end,
	},
	{
		"neovim/nvim-lspconfig",
		opts = {
			servers = {
				spicedb_lsp = {
					mason = false, -- not a mason package; binary is on PATH via brew
					cmd = { "spicedb", "lsp" },
					filetypes = { "authzed" },
					root_markers = { ".git", "schema.zed" },
				},
			},
		},
	},
}

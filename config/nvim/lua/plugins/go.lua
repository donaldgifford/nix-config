return {
	{
		"neovim/nvim-lspconfig",
		opts = {
			servers = {
				gopls = {
					settings = {
						gopls = {
							-- Replace "your_tag" with your actual build tag, e.g., "integration" or "wireinject"
							buildFlags = { "-tags=integration" },
						},
					},
				},
			},
		},
	},
}

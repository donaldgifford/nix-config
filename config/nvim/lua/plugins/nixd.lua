return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        nixd = {
          settings = {
            nixd = {
              -- Auto-fetch missing flake inputs instead of prompting on every open
              options = {
                autoArchive = true,
              },
              eval = {
                autoArchive = true,
              },
            },
          },
        },
      },
    },
  },
}

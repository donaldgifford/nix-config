return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        taplo = {
          on_init = function(client)
            client.handle_error = function(_, err)
              if err and err.error and err.error.code == -32600 then
                return
              end
            end
          end,
        },
      },
    },
  },
}

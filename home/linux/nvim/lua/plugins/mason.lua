return {
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        -- go
        "gomodifytags",
        "gofumpt",
        "goimports",
        "golangci-lint",
        "golines",
        "gomodifytags",
        "gopls",
        "impl",
        "delve",
        -- make
        "checkmake",
        "cmakelang",
        "cmakelint",
        "codelldb",
        "neocmakelsp",
        -- shell
        "shfmt",
        "shellcheck",
        -- markdown
        "markdown-toc",
        "markdownlint-cli2",
        "marksman",
        "markdown-toc",
        -- tf
        "terraform-ls",
        "tflint",
        -- yaml
        "yamlfmt",
        "yamllint",
        "yaml-language-server",
        "prettier",
        -- helm
        "helm-ls",
        -- docker
        "hadolint",
        -- rust
        "bacon",
        "bacon-ls",
      },
    },
  },
}

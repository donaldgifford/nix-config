return {
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      default_ft_opts = {
        timeout_ms = 8000,
        async = false,
        quiet = false,
        lsp_format = "fallback",
      },
      formatters_by_ft = {
        go = { "goimports", "gofumpt", "golines" },
        yaml = { "yamlfmt" },
        -- yaml = { "prettier" },
        helm = { "helm_ls" },
        -- cmake = { "cmake_format" },
        nix = { "nixfmt" },
        -- ["markdown"] = { "prettier", "markdownlint-cli2", "markdown-toc" },
        ["markdown"] = { "markdownlint-cli2", "prettier", "markdown-toc" },
        ["markdown.mdx"] = { "prettier", "markdownlint-cli2", "markdown-toc" },
        hcl = { "terragrunt_hclfmt", "packer_fmt" },
        terraform = { "terraform_fmt" },
        tf = { "terraform_fmt" },
        ["terraform-vars"] = { "terraform_fmt" },
        toml = { "taplo" },
        rust = { "rustfmt" },
      },
      formatters = {
        yamlfmt = {
          args = { "-" },
        },
        golines = {
          prepend_args = { "-m", "120" },
        },
        terragrunt_hclfmt = {
          args = { "hcl", "fmt", "--file", "$FILENAME" },
        },
        helm_ls = {
          command = "helm_ls",
          args = { "serve", "--format" }, -- Use the serve command with the --format flag
          -- Set the filetypes it applies to if not already covered in formatters_by_ft
          filetypes = { "helm", "yaml" },
          -- Define root patterns to help the language server identify project root
          rootPatterns = { "Chart.yaml" },
        },
      },
    },
  },
}

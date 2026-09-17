return {
  "mfussenegger/nvim-lint",
  optional = true,
  dependencies = {
    {
      "mason-org/mason.nvim",
      opts = { ensure_installed = { "golangci-lint", "actionlint", "yamllint" } },
    },
  },
  opts = {
    linters_by_ft = {
      go = { "golangcilint" },
      sh = { "shellcheck" },
      make = { "checkmake" },
      cmake = { "cmakelint" },
      dockerfile = { "hadolint" },
      markdown = { "markdownlint-cli2" },
      yaml = { "yamllint", "actionlint" },
      rust = { "clippy" },
      nix = { "statix" },
    },
    linters = {
      actionlint = {
        condition = function(ctx)
          return ctx.filename:match("%.github/workflows/.*%.ya?ml$") ~= nil
        end,
      },
      yamllint = {
        condition = function(ctx)
          -- Run yamllint on all yaml EXCEPT GitHub workflow files
          return ctx.filename:match("%.github/workflows/.*%.ya?ml$") == nil
        end,
      },
    },
  },
}

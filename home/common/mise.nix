{
  config,
  pkgs,
  lib,
  ...
}:

{
  programs.mise = {
    enable = true;
    enableZshIntegration = true;
    enableNushellIntegration = true;

    # Global tools — available everywhere, not tied to a project
    globalConfig = {
      tools = {
        go = "latest";
        node = "24";
        rust = "1.93.1";
        uv = "latest";
        markdownlint-cli2 = "0.18.1";
        yamlfmt = "latest";
        yamllint = "latest";
        prettier = "3.7.4";
        golines = "latest";
        golangci-lint = "latest";
        shfmt = "latest";
        shellcheck = "latest";
        ruff = "latest";
        python = "3.13";
        marksman = "latest";
        terragrunt = "latest";
        terraform = "latest";
        terraform-docs = "latest";
        tflint = "latest";
        packer = "latest";
        opentofu = "latest";
        kubectl = "latest";
        goreleaser = "latest";
        rust-analyzer = "latest";
        "cargo:tree-sitter-cli" = "latest";
        # donaldgifford
        "github:donaldgifford/forge" = "latest";
        "github:donaldgifford/docz" = "latest";
        "github:donaldgifford/makefmt" = "latest";
        # go
        "go:golang.org/x/tools/cmd/goimports" = "latest";
        "go:golang.org/x/tools/gopls" = "latest";
        "go:github.com/spf13/cobra-cli" = "latest";
        hugo = "0.140.2";
        helm = "3.19.0";
        helm-cr = "1.8.1";
        helm-ct = "3.14.0";
        helm-diff = "3.15.0";
        helm-docs = "1.14.2";
        typst = "latest";

      };

      settings = {
        # Auto-install tools when entering a directory with a mise.toml
        not_found_auto_install = true;
        # How often to check plugins for updates
        plugin_autoupdate_last_check_duration = "1 week";
        # Directories to always trust (no confirmation prompt)
        trusted_config_paths = [
          "~/code"
          "~/work"
        ];
        # Load .env files automatically
        env_file = ".env";
        # Use uv for Python venvs (faster than pip)
        python = {
          uv_venv_auto = true;
          # uv_venv_auto = "create|source";
        };
      };
    };
  };
}

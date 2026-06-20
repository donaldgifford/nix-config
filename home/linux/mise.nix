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
        uv = "latest";
        markdownlint-cli2 = "latest";
        yamlfmt = "latest";
        yamllint = "latest";
        prettier = "latest";
        golines = "latest";
        golangci-lint = "latest";
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

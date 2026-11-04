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

    # Global tools live in config/mise/conf.d/global.toml (symlinked via
    # configs.nix) so renovate can manage version pins via annotations.
    # Settings stay here since they're not version-tracked.
    globalConfig = {
      settings = {
        # config.toml is a read-only Nix store link, so send `mise use -g`
        # writes to the repo-backed fragment instead (mise >= 2026.10.17).
        # Tools already declared elsewhere stay in the file that declares them.
        write_targets.tools = "~/.config/mise/conf.d/global.toml";
        # GitHub token for mise (private aqua registry, release downloads,
        # rate limits), read from the login keychain. If the item is missing,
        # mise falls back to its other token sources. An exported GITHUB_TOKEN
        # or MISE_GITHUB_TOKEN takes priority over this. See START_HERE.md.
        github.credential_command = "security find-generic-password -s mise-aqua-registry -w";
        # Auto-install tools when entering a directory with a mise.toml
        not_found_auto_install = true;
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

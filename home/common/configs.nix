{
  config,
  pkgs,
  lib,
  ...
}:

let
  dotfiles = "${config.home.homeDirectory}/code/nix-config/config";
  link = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";

in
{
  xdg.configFile = {
    "ghostty/config".source = link "ghostty/config";
    "sesh/sesh.toml".source = link "sesh/sesh.toml";
    # eza theme comes from EZA_CONFIG_DIR → config/themes/<name>/eza/theme.yml
    # (repo config/eza/*.yml are reference copies, not linked)
    "btop/btop.conf".source = link "btop/btop.conf";
    "btop/themes/tokyo-night.theme".source = link "btop/themes/tokyo-night.theme";
    "bat/config".source = link "bat/config";
    "bat/themes/tokyonight/Enki-Tokyo-Night.tmTheme".source =
      link "bat/themes/tokyonight/Enki-Tokyo-Night.tmTheme";
    "yazi/theme.toml".source = link "yazi/theme.toml";
    "yazi/yazi.toml".source = link "yazi/yazi.toml";
    "yazi/package.toml".source = link "yazi/package.toml";
    "starship.toml".source = link "starship/starship.toml";
    "lazygit/config.yml".source = link "lazygit/config.yml";
    # "gh-dash/config.yml".source = link "gh-dash/config.yml";
    # "gh/config.yml".source = link "gh/config.yml";
    "nvim".source = link "nvim";
    "diffnav/config.yml".source = link "diffnav/config.yml";
    "1Password/ssh/agent.toml".source = link "1Password/ssh/agent.toml";
    "mise/conf.d/global.toml".source = link "mise/conf.d/global.toml";
    # Theme switcher: whole dir (per-theme assets + `current` symlink live here)
    "themes".source = link "themes";
    "ghostty/themes".source = link "ghostty/themes";
    "bat/themes/warm-burnout/Warm Burnout Dark.tmTheme".source =
      link "bat/themes/warm-burnout/Warm Burnout Dark.tmTheme";
    "hunk/config.toml".source = link "hunk/config.toml";
    "herdr/config.toml".source = link "herdr/config.toml";
    "herdr/scripts/agent-picker.sh".source = link "herdr/scripts/agent-picker.sh";
    # Nushell: HM owns config.nu/env.nu (on macOS they live under
    # ~/Library/Application Support/nushell); modules + overlays are ours and
    # are picked up via NU_LIB_DIRS in shell.nix. Subdir links, not the whole
    # dir, so this coexists with HM's own files on Linux (~/.config/nushell).
    "nushell/modules".source = link "nushell/modules";
    "nushell/overlays".source = link "nushell/overlays";
    # opencode owns the rest of ~/.config/opencode (plugin node_modules,
    # package.json, its own .gitignore) so link files, not the dir. `force`
    # replaces the stub opencode.jsonc it wrote on first run.
    "opencode/opencode.jsonc" = {
      source = link "opencode/opencode.jsonc";
      force = true;
    };
    "opencode/themes/tokyonight.json".source = link "opencode/tokyonight.json";
    "opencode/themes/tokyonight_storm.json".source = link "opencode/tokyonight_storm.json";
  };
}

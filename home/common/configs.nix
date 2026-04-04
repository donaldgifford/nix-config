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
    "eza/theme.yml".source = link "eza/theme.yml";
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
  };
}

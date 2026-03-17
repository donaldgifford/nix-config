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
  };
}

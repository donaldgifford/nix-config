{
  config,
  pkgs,
  lib,
  ...
}:

let
  fontDir = ./fonts;

  # macOS uses ~/Library/Fonts, Linux uses ~/.local/share/fonts
  targetPrefix = if pkgs.stdenv.isDarwin then "Library/Fonts" else ".local/share/fonts";
in
{
  home.file = {
    "${targetPrefix}/BerkeleyMonoNFRegular" = {
      source = "${fontDir}/BerkeleyMonoNerdFontRegular";
      recursive = true;
    };
    "${targetPrefix}/BerkeleyMonoNFSemiCondensed" = {
      source = "${fontDir}/BerkeleyMonoNerdFontSemiCondensed";
      recursive = true;
    };
  };
}

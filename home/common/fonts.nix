{
  config,
  pkgs,
  lib,
  ...
}:

let
  fontDir = ./fonts;
  hasBerkeleyMono = builtins.pathExists "${fontDir}/BerkeleyMonoNerdFontRegular";

  targetPrefix = if pkgs.stdenv.isDarwin then "Library/Fonts" else ".local/share/fonts";
in
{
  home.activation.installFonts = lib.mkIf hasBerkeleyMono (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "$HOME/${targetPrefix}/BerkeleyMonoNFRegular"
      mkdir -p "$HOME/${targetPrefix}/BerkeleyMonoNFSemiCondensed"
      cp -f ${fontDir}/BerkeleyMonoNerdFontRegular/*.ttf "$HOME/${targetPrefix}/BerkeleyMonoNFRegular/"
      cp -f ${fontDir}/BerkeleyMonoNerdFontSemiCondensed/*.ttf "$HOME/${targetPrefix}/BerkeleyMonoNFSemiCondensed/"
    ''
  );
}

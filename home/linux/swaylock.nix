{
  config,
  pkgs,
  lib,
  ...
}:

{
  programs.swaylock = {
    enable = true;

    settings = {
      # Catppuccin Mocha color scheme
      color = "1e1e2e";
      font = "JetBrainsMono Nerd Font";
      font-size = 16;

      indicator-radius = 100;
      indicator-thickness = 7;
      indicator-caps-lock = true;

      # Ring colors
      ring-color = "cba6f7";
      ring-ver-color = "89b4fa";
      ring-wrong-color = "f38ba8";
      ring-clear-color = "a6e3a1";

      # Inside colors
      inside-color = "1e1e2e";
      inside-ver-color = "1e1e2e";
      inside-wrong-color = "1e1e2e";
      inside-clear-color = "1e1e2e";

      # Key highlight
      key-hl-color = "a6e3a1";
      bs-hl-color = "f38ba8";

      # Text
      text-color = "cdd6f4";
      text-ver-color = "89b4fa";
      text-wrong-color = "f38ba8";
      text-clear-color = "a6e3a1";

      # Line (separator between ring and inside)
      line-color = "1e1e2e";
      line-ver-color = "1e1e2e";
      line-wrong-color = "1e1e2e";
      line-clear-color = "1e1e2e";

      separator-color = "00000000";

      # Show failed attempts counter
      show-failed-attempts = true;
    };
  };
}

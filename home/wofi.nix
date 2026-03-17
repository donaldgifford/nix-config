{
  config,
  pkgs,
  lib,
  ...
}:

{
  programs.wofi = {
    enable = true;

    settings = {
      width = 600;
      height = 400;
      location = "center";
      show = "drun";
      prompt = "Launch";
      filter_rate = 100;
      allow_markup = true;
      no_actions = true;
      halign = "fill";
      orientation = "vertical";
      content_halign = "fill";
      insensitive = true;
      allow_images = true;
      image_size = 32;
      gtk_dark = true;
    };

    style = ''
      window {
        background-color: #1e1e2e;
        border: 2px solid #cba6f7;
        border-radius: 12px;
      }

      #input {
        background-color: #313244;
        color: #cdd6f4;
        border: none;
        border-radius: 8px;
        padding: 8px 12px;
        margin: 8px;
        font-size: 14px;
      }

      #input:focus {
        border: 1px solid #cba6f7;
      }

      #inner-box {
        background-color: transparent;
        margin: 0 8px 8px 8px;
      }

      #outer-box {
        background-color: transparent;
      }

      #entry {
        padding: 6px 12px;
        border-radius: 6px;
        color: #cdd6f4;
      }

      #entry:selected {
        background-color: #313244;
        color: #cba6f7;
      }

      #entry:hover {
        background-color: #45475a;
      }

      #text {
        color: #cdd6f4;
        font-size: 13px;
      }

      #text:selected {
        color: #cba6f7;
      }

      #img {
        margin-right: 8px;
      }
    '';
  };
}

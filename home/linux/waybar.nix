{
  config,
  pkgs,
  lib,
  ...
}:

{
  programs.waybar = {
    enable = true;

    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 30;

        modules-left = [
          "sway/workspaces"
          "sway/mode"
          "sway/scratchpad"
        ];
        modules-center = [ "sway/window" ];
        modules-right = [
          "cpu"
          "memory"
          "temperature"
          "pulseaudio"
          "network"
          "clock"
          "tray"
        ];

        "sway/workspaces" = {
          disable-scroll = true;
          all-outputs = true;
          format = "{icon}";
          format-icons = {
            "1" = "1";
            "2" = "2";
            "3" = "3";
            "4" = "4";
            "5" = "5";
            urgent = "";
            focused = "";
            default = "";
          };
        };

        "sway/mode" = {
          format = "<span style='italic'>{}</span>";
        };

        "sway/scratchpad" = {
          format = "{icon} {count}";
          show-empty = false;
          format-icons = [
            ""
            ""
          ];
          tooltip = true;
          tooltip-format = "{app}: {title}";
        };

        cpu = {
          format = " {usage}%";
          interval = 2;
          tooltip = false;
        };

        memory = {
          format = " {}%";
          interval = 5;
          tooltip-format = "{used:0.1f}G / {total:0.1f}G";
        };

        temperature = {
          format = " {temperatureC}°C";
          critical-threshold = 80;
          format-critical = " {temperatureC}°C";
          tooltip = false;
        };

        network = {
          format-wifi = " {essid} ({signalStrength}%)";
          format-ethernet = " {ipaddr}/{cidr}";
          format-disconnected = "⚠ Disconnected";
          format-linked = " {ifname} (No IP)";
          tooltip-format = "{ifname}: {ipaddr}\nUp: {bandwidthUpBits} Down: {bandwidthDownBits}";
          on-click = "foot -e nmtui";
        };

        pulseaudio = {
          format = "{icon} {volume}%";
          format-muted = " muted";
          format-icons = {
            headphone = "";
            default = [
              ""
              ""
              ""
            ];
          };
          on-click = "pamixer -t";
          on-click-right = "pavucontrol";
          scroll-step = 5;
        };

        clock = {
          format = " {:%H:%M}";
          format-alt = " {:%Y-%m-%d %H:%M:%S}";
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        };

        tray = {
          spacing = 10;
          icon-size = 16;
        };
      };
    };

    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font";
        font-size: 13px;
        border: none;
        border-radius: 0;
        min-height: 0;
      }

      window#waybar {
        background-color: #1e1e2e;
        color: #cdd6f4;
        border-bottom: 2px solid #313244;
      }

      .modules-left,
      .modules-center,
      .modules-right {
        padding: 0 4px;
      }

      #workspaces button {
        padding: 0 8px;
        color: #6c7086;
        border-bottom: 3px solid transparent;
        transition: all 0.2s ease;
      }

      #workspaces button.focused,
      #workspaces button.active {
        color: #cdd6f4;
        border-bottom: 3px solid #cba6f7;
      }

      #workspaces button.urgent {
        color: #f38ba8;
        border-bottom: 3px solid #f38ba8;
      }

      #workspaces button:hover {
        background: #313244;
        color: #cdd6f4;
      }

      #mode {
        color: #f9e2af;
        padding: 0 10px;
      }

      #clock,
      #cpu,
      #memory,
      #temperature,
      #network,
      #pulseaudio,
      #tray,
      #scratchpad {
        padding: 0 12px;
        color: #cdd6f4;
      }

      #window {
        color: #a6adc8;
        font-style: italic;
      }

      #cpu        { color: #89b4fa; }
      #memory     { color: #a6e3a1; }
      #clock      { color: #cba6f7; font-weight: bold; }
      #network    { color: #89dceb; }
      #pulseaudio { color: #f5c2e7; }

      #temperature.critical {
        color: #f38ba8;
        animation: blink 1s steps(1) infinite;
      }

      @keyframes blink {
        to { color: #1e1e2e; background-color: #f38ba8; }
      }

      #tray > .passive {
        -gtk-icon-effect: dim;
      }

      #tray > .needs-attention {
        -gtk-icon-effect: highlight;
        background-color: #f38ba8;
      }
    '';
  };
}

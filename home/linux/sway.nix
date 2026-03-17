{
  config,
  pkgs,
  lib,
  ...
}:

{
  wayland.windowManager.sway = {
    enable = true;

    # package = null tells HM to manage the config WITHOUT installing sway.
    # Sway is already installed at the system level in configuration.nix.
    # If you let HM install it too you get a version conflict.
    package = null;

    config = {
      modifier = "Mod4"; # Super/Windows key
      terminal = "ghostty";
      menu = "wofi --show drun";

      fonts = {
        names = [ "JetBrainsMono Nerd Font" ];
        size = 10.0;
      };

      gaps = {
        inner = 8;
        outer = 4;
      };

      # Waybar handles the bar — disable sway's built-in bar
      bars = [ ];

      input = {
        "type:keyboard" = {
          xkb_layout = "us";
          repeat_delay = "300";
          repeat_rate = "50";
        };
        "type:touchpad" = {
          tap = "enabled";
          natural_scroll = "enabled";
          dwt = "enabled";
        };
      };

      # Output configuration — adjust resolution/position to your monitor(s).
      # Run `swaymsg -t get_outputs` to list available outputs and their names.
      output = {
        # "*" = { bg = "#1e1e2e solid_color"; };
        "DP-2" = {
          mode = "3840x2560@120Hz";
          scale = "2"; # effective 1920x1280 — matches Mac behavior
          bg = "#1e1e2e solid_color";
        };
      };

      keybindings =
        let
          mod = "Mod4";
        in
        {
          # ── Core ───────────────────────────────────────────────────────────
          "${mod}+Return" = "exec foot";
          "${mod}+d" = "exec wofi --show drun";
          "${mod}+Shift+q" = "kill";
          "${mod}+Shift+e" = "exec swaynag -t warning -m 'Exit sway?' -B 'Yes' 'swaymsg exit'";
          "${mod}+Shift+c" = "reload";

          # ── Focus ──────────────────────────────────────────────────────────
          "${mod}+h" = "focus left";
          "${mod}+j" = "focus down";
          "${mod}+k" = "focus up";
          "${mod}+l" = "focus right";

          # ── Move ───────────────────────────────────────────────────────────
          "${mod}+Shift+h" = "move left";
          "${mod}+Shift+j" = "move down";
          "${mod}+Shift+k" = "move up";
          "${mod}+Shift+l" = "move right";

          # ── Layout ─────────────────────────────────────────────────────────
          "${mod}+v" = "splith";
          "${mod}+b" = "splitv";
          "${mod}+s" = "layout stacking";
          "${mod}+w" = "layout tabbed";
          "${mod}+e" = "layout toggle split";
          "${mod}+f" = "fullscreen toggle";
          "${mod}+Shift+space" = "floating toggle";
          "${mod}+space" = "focus mode_toggle";

          # ── Resize ─────────────────────────────────────────────────────────
          "${mod}+r" = "mode resize";

          # ── Workspaces ─────────────────────────────────────────────────────
          "${mod}+1" = "workspace number 1";
          "${mod}+2" = "workspace number 2";
          "${mod}+3" = "workspace number 3";
          "${mod}+4" = "workspace number 4";
          "${mod}+5" = "workspace number 5";
          "${mod}+6" = "workspace number 6";
          "${mod}+7" = "workspace number 7";
          "${mod}+8" = "workspace number 8";
          "${mod}+9" = "workspace number 9";

          "${mod}+Shift+1" = "move container to workspace number 1";
          "${mod}+Shift+2" = "move container to workspace number 2";
          "${mod}+Shift+3" = "move container to workspace number 3";
          "${mod}+Shift+4" = "move container to workspace number 4";
          "${mod}+Shift+5" = "move container to workspace number 5";
          "${mod}+Shift+6" = "move container to workspace number 6";
          "${mod}+Shift+7" = "move container to workspace number 7";
          "${mod}+Shift+8" = "move container to workspace number 8";
          "${mod}+Shift+9" = "move container to workspace number 9";

          # ── Screenshot ─────────────────────────────────────────────────────
          "Print" = "exec grim ~/screenshots/$(date +%Y%m%d_%H%M%S).png";
          "Shift+Print" = "exec grim -g \"$(slurp)\" ~/screenshots/$(date +%Y%m%d_%H%M%S).png";

          # ── Volume ─────────────────────────────────────────────────────────
          "XF86AudioRaiseVolume" = "exec pamixer -i 5";
          "XF86AudioLowerVolume" = "exec pamixer -d 5";
          "XF86AudioMute" = "exec pamixer -t";
          "XF86AudioPlay" = "exec playerctl play-pause";
          "XF86AudioNext" = "exec playerctl next";
          "XF86AudioPrev" = "exec playerctl previous";

          # ── Brightness ─────────────────────────────────────────────────────
          "XF86MonBrightnessUp" = "exec brightnessctl set +5%";
          "XF86MonBrightnessDown" = "exec brightnessctl set 5%-";

          # ── Lock ───────────────────────────────────────────────────────────
          # "${mod}+Shift+l" = "exec swaylock -f -c 000000";
        };

      startup = [
        # Status bar
        { command = "waybar"; }

        # Create screenshots directory
        { command = "mkdir -p ~/screenshots"; }

        # Idle management: lock after 5min, screen off after 10min
        {
          command = ''
            swayidle -w \
              timeout 300 'swaylock -f -c 000000' \
              timeout 600 'swaymsg "output * dpms off"' \
              resume 'swaymsg "output * dpms on"' \
              before-sleep 'swaylock -f -c 000000'
          '';
        }
      ];
    };

    # Extra config that doesn't fit the structured options above
    extraConfig = ''

      # Resize mode
      #      mode "resize" {
      #        bindsym h resize shrink width 10px
      #        bindsym j resize grow height 10px
      #        bindsym k resize shrink height 10px
      #        bindsym l resize grow width 10px
      #        bindsym Return mode "default"
      #        bindsym Escape mode "default"
      #      }

            # Float certain windows by default
            for_window [app_id="pavucontrol"]   floating enable
            for_window [app_id="blueman-manager"] floating enable
            for_window [title="1Password"]      floating enable

            # Inhibit idle when any app is fullscreen
            for_window [class=".*"] inhibit_idle fullscreen
            for_window [app_id=".*"] inhibit_idle fullscreen
    '';
  };
}

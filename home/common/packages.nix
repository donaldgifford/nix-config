{
  config,
  pkgs,
  lib,
  ...
}:

{
  home.packages =
    with pkgs;
    [
      # ── Core CLI ────────────────────────────────────────────────────────────
      ripgrep
      fd
      bat
      eza
      fzf
      zoxide
      jq
      yq-go
      delta
      lazygit
      httpie
      tree
      watch
      curl
      wget
      unzip

      # ── GNU tools (macOS ships BSD versions) ────────────────────────────────
      coreutils
      gnused
      gnugrep
      gawk
      findutils

      # ── Cloud / Infra ───────────────────────────────────────────────────────
      awscli2

      # ── Nix tooling ─────────────────────────────────────────────────────────
      nixd
      nil
      nixfmt
      statix
      deadnix
      nix-direnv
      nvd

      # ── Git / GitHub ────────────────────────────────────────────────────────
      gh

      # ── Kubernetes ──────────────────────────────────────────────────────────
      krew

      # ── Misc ────────────────────────────────────────────────────────────────
      starship
      sesh
      direnv
      mise
      gh # GitHub CLI
      btop
      yazi
    ]
    ++ lib.optionals pkgs.stdenv.isLinux [
      # ── Linux-only ──────────────────────────────────────────────────────────
      # ── 1Password ────────────────────────────────────────────────────────────
      _1password-cli # op CLI — required for SSH agent and git signing
      _1password-gui # required for op-ssh-sign (git commit signing)

      # ── Wayland / Sway utilities ─────────────────────────────────────────────
      wl-clipboard # wl-copy / wl-paste
      grim # screenshot
      slurp # region selection for screenshots
      brightnessctl # brightness control
      pamixer # volume control
      playerctl # media player control
      pavucontrol # GUI volume control
      xdg-utils

    ]
    ++ lib.optionals pkgs.stdenv.isDarwin [
      # ── macOS-only ──────────────────────────────────────────────────────────
      ghostty-bin
      checkmake
    ];
}

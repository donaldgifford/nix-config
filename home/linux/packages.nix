{
  config,
  pkgs,
  lib,
  ...
}:

{
  home.packages = with pkgs; [
    # ── Shell utilities ──────────────────────────────────────────────────────
    eza # modern ls
    bat # modern cat
    ripgrep # fast grep
    fd # fast find
    fzf # fuzzy finder
    zoxide # smart cd
    delta # better git diffs
    jq # json
    yq # yaml
    htop
    unzip
    zip
    curl
    wget

    # ── Dev tooling ──────────────────────────────────────────────────────────
    # mise manages language runtimes (go, node, python, ruby) per project.
    # Install runtimes with: mise install go@latest node@lts etc.
    # mise
    python313
    nodejs_24

    # ── Cloud / Infra ────────────────────────────────────────────────────────
    awscli2
    kubectl
    k9s
    helm
    terraform
    fluxcd

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
  ];
}

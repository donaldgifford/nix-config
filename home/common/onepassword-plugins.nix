{
  inputs,
  pkgs,
  ...
}:

{
  imports = [ inputs._1password-shell-plugins.hmModules.default ];

  programs._1password-shell-plugins = {
    enable = false;
    plugins = with pkgs; [
      # NOTE: gh intentionally not wrapped — breaks non-interactive use
      # (e.g. Claude Code). Use `gh auth login` once; it stores the token
      # in macOS Keychain / Linux secret service.
      awscli2
      tea # Gitea CLI
      wrangler # Cloudflare Workers CLI
      cargo
      # TODO: come back and enable + configure these
      # terraform
      # vault
    ];
  };
}

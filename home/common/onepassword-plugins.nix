{
  inputs,
  pkgs,
  ...
}:

{
  imports = [ inputs._1password-shell-plugins.hmModules.default ];

  programs._1password-shell-plugins = {
    enable = true;
    plugins = with pkgs; [
      gh
      awscli2
      gitea
      argocd
      wrangler # Cloudflare Workers CLI
      cargo
      # TODO: come back and enable + configure these
      # terraform
      # vault
    ];
  };
}

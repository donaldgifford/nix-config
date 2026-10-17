{ pkgs, ... }:

# temporal-oidc: the temporal CLI with a refreshed Keycloak token, so the
# 5-minute access token never means logging in again. A command on PATH
# rather than a zsh function, so just recipes (bash) and scripts in other
# repos can call it too. macOS only for now: it keeps the refresh token in
# the Keychain (/usr/bin/security). temporal itself comes from mise.
let
  temporal-oidc = pkgs.writeShellApplication {
    name = "temporal-oidc";
    runtimeInputs = with pkgs; [
      curl
      jq
    ];
    text = builtins.readFile ./temporal-oidc/temporal-oidc.sh;
  };
in
{
  home.packages = [ temporal-oidc ];
}

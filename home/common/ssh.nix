{
  config,
  pkgs,
  lib,
  ...
}:

let
  # 1Password SSH agent socket differs between platforms
  agentSocket =
    if pkgs.stdenv.isDarwin then
      "\"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\""
    else
      "~/.1password/agent.sock";
in
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks."*" = {
      extraOptions = {
        IdentityAgent = agentSocket;
      };
    };
  };
}

{
  config,
  pkgs,
  lib,
  ...
}: {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    # Deliberately still matchBlocks: the workstation builds with
    # home-manager-stable (25.11), which has no `programs.ssh.settings` yet.
    # Migrate to match home/common/ssh.nix when the stable input moves to 26.05+.
    matchBlocks."*" = {
      identityAgent = "~/.1password/agent.sock";
    };
  };
}

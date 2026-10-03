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
    # 1Password SSH Bookmarks auto-generated config — must come first so
    # per-host key mappings take precedence over our own blocks.
    includes = [ "~/.ssh/1Password/config" ];
    # `settings` (replaces the deprecated matchBlocks) uses upstream OpenSSH
    # directive names. NOTE: home/linux/ssh.nix must stay on matchBlocks —
    # the workstation's home-manager-stable (25.11) has no `settings` option.
    settings = {
      "*" = {
        IdentityAgent = agentSocket;
        # Without this, ssh tries every key in the 1P agent per connection
        # and servers kick us out with "Too many authentication failures"
        # before hitting the right one.
        IdentitiesOnly = "yes";
      };
      # ── Proxmox VMs ────────────────────────────────────────────────────────

      # ── UCG Fiber ───────────────────────────────────────────────────────────
      "ucg" = {
        Hostname = "10.10.10.1";
        User = "root";
        IdentityFile = "~/.ssh/root_home.pub";
      };

      # ── DNS Servers ─────────────────────────────────────────────────────────

      # NOTE: these are all the old raspberrypis that need to get removed.
      "dns01" = {
        Hostname = "10.10.10.53";
        User = "rpi";
        IdentityFile = "~/.ssh/root_home.pub";
      };
      "dns02" = {
        Hostname = "10.10.10.54";
        User = "rpi";
        IdentityFile = "~/.ssh/root_home.pub";
      };
      "dns03" = {
        Hostname = "10.10.10.194";
        User = "rpi";
        IdentityFile = "~/.ssh/root_home.pub";
      };
      "dns04" = {
        Hostname = "10.10.10.200";
        User = "rpi";
        IdentityFile = "~/.ssh/root_home.pub";
      };

      # ── Intel NUC ─────────────────────────────────────────────────────────
      # NOTE: Old ns2, migrated away from using as nameserver.
      "nuc" = {
        Hostname = "10.10.11.187";
        User = "root";
        IdentityFile = "~/.ssh/root_home.pub";
      };
      # ── DNS Servers ─────────────────────────────────────────────────────────
      # m01 and m02 beelink minis that are set as nameservers.
      "ns1 m02 10.10.10.190" = {
        Hostname = "10.10.10.190";
        User = "root";
        IdentityFile = "~/.ssh/root_home.pub";
      };

      "ns1-servers m02-servers 10.10.11.190" = {
        Hostname = "10.10.11.190";
        User = "root";
        IdentityFile = "~/.ssh/root_home.pub";
      };

      "ns2 m01 10.10.10.191" = {
        Hostname = "10.10.10.191";
        User = "root";
        IdentityFile = "~/.ssh/root_home.pub";
      };

      "ns2-servers m01-servers 10.10.11.191" = {
        Hostname = "10.10.11.191";
        User = "root";
        IdentityFile = "~/.ssh/root_home.pub";
      };

      # ── NixOS Workstation ───────────────────────────────────────────────────
      "nixos" = {
        Hostname = "10.10.10.14";
        User = "donald";
        IdentityFile = "~/.ssh/donald.pub";
      };

      # ── GitHub ──────────────────────────────────────────────────────────────
      "github.com" = {
        User = "git";
        IdentityFile = "~/.ssh/github.pub";
      };

      # ── Proxmox Hosts ────────────────────────────────────────────────────────

      # ── r740a (fartlab) ───────────────────────────────────────────────────
      "r740a 10.10.11.20" = {
        Hostname = "10.10.11.20";
        User = "root";
        IdentityFile = "~/.ssh/root_home.pub";
      };
      # ── r640 (fartlab) ───────────────────────────────────────────────────
      "r640a 10.10.11.21" = {
        Hostname = "10.10.11.21";
        User = "root";
        IdentityFile = "~/.ssh/root_home.pub";
      };
      # ── srv01 (fartlab) ───────────────────────────────────────────────────
      "srv01 10.10.11.40" = {
        Hostname = "10.10.11.40";
        User = "root";
        IdentityFile = "~/.ssh/root_home.pub";
      };

      # ── Proxmox VMs ────────────────────────────────────────────────────────
    };
  };
}

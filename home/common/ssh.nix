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

      # ── Proxmox Servers ────────────────────────────────────────────────────
      "proxmox1" = {
        Hostname = "proxmox1.servers.internal";
        User = "root";
        IdentityFile = "~/.ssh/root_home.pub";
      };
      "proxmox1-terraform" = {
        Hostname = "proxmox1.servers.internal";
        User = "terraform";
        IdentityFile = "~/.ssh/admin_poop_systems.pub";
      };
      "proxmox2" = {
        Hostname = "proxmox2.servers.internal";
        User = "root";
        IdentityFile = "~/.ssh/root_home.pub";
      };
      "proxmox2-terraform" = {
        Hostname = "proxmox2.servers.internal";
        User = "terraform";
        IdentityFile = "~/.ssh/admin_poop_systems.pub";
      };
      "proxmox3" = {
        Hostname = "proxmox3.servers.internal";
        User = "root";
        IdentityFile = "~/.ssh/root_home.pub";
      };
      "proxmox3-terraform" = {
        Hostname = "proxmox3.servers.internal";
        User = "terraform";
        IdentityFile = "~/.ssh/admin_poop_systems.pub";
      };
      "proxmox4" = {
        Hostname = "proxmox4.servers.internal";
        User = "root";
        IdentityFile = "~/.ssh/root_home.pub";
      };
      "proxmox4-terraform" = {
        Hostname = "proxmox4.servers.internal";
        User = "terraform";
        IdentityFile = "~/.ssh/admin_poop_systems.pub";
      };
      "proxmox5" = {
        Hostname = "proxmox5.servers.internal";
        User = "root";
        IdentityFile = "~/.ssh/root_home.pub";
      };
      "proxmox5-terraform" = {
        Hostname = "proxmox5.servers.internal";
        User = "terraform";
        IdentityFile = "~/.ssh/admin_poop_systems.pub";
      };
      "proxmox6" = {
        Hostname = "proxmox6.servers.internal";
        User = "root";
        IdentityFile = "~/.ssh/root_home.pub";
      };
      "proxmox6-terraform" = {
        Hostname = "proxmox6.servers.internal";
        User = "terraform";
        IdentityFile = "~/.ssh/admin_poop_systems.pub";
      };

      # ── Proxmox VMs ────────────────────────────────────────────────────────

      # ── UCG Fiber ───────────────────────────────────────────────────────────
      "ucg" = {
        Hostname = "10.10.10.1";
        User = "root";
        IdentityFile = "~/.ssh/root_home.pub";
      };

      # ── DNS Servers ─────────────────────────────────────────────────────────
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

      "ns1 10.10.10.190" = {
        Hostname = "10.10.10.190";
        User = "root";
        IdentityFile = "~/.ssh/root_home.pub";
      };

      "ns2 10.10.10.191" = {
        Hostname = "10.10.10.191";
        User = "root";
        IdentityFile = "~/.ssh/root_home.pub";
      };

      "ns3 10.10.10.192" = {
        Hostname = "10.10.10.192";
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

      # ── Forgejo (fartlab) ───────────────────────────────────────────────────
      "git.fartlab.dev" = {
        User = "git";
        IdentityFile = "~/.ssh/donald.pub";
      };
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
      # ── beelink01 (fartlab) ───────────────────────────────────────────────────
      "beelink01 10.10.11.30" = {
        Hostname = "10.10.11.30";
        User = "root";
        IdentityFile = "~/.ssh/root_home.pub";
      };
      # ── beelink02 (fartlab) ───────────────────────────────────────────────────
      "beelink02 10.10.11.31" = {
        Hostname = "10.10.11.31";
        User = "root";
        IdentityFile = "~/.ssh/root_home.pub";
      };
      # ── beelink03 (fartlab) ───────────────────────────────────────────────────
      "beelink03 10.10.11.32" = {
        Hostname = "10.10.11.32";
        User = "root";
        IdentityFile = "~/.ssh/root_home.pub";
      };
    };
  };
}

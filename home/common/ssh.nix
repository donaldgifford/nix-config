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
    matchBlocks = {
      "*" = {
        extraOptions = {
          IdentityAgent = agentSocket;
          # Without this, ssh tries every key in the 1P agent per connection
          # and servers kick us out with "Too many authentication failures"
          # before hitting the right one.
          IdentitiesOnly = "yes";
        };
      };

      # ── Proxmox Servers ────────────────────────────────────────────────────
      "proxmox1" = {
        hostname = "proxmox1.servers.internal";
        user = "root";
        extraOptions.IdentityFile = "~/.ssh/root_home.pub";
      };
      "proxmox1-terraform" = {
        hostname = "proxmox1.servers.internal";
        user = "terraform";
        extraOptions.IdentityFile = "~/.ssh/admin_poop_systems.pub";
      };
      "proxmox2" = {
        hostname = "proxmox2.servers.internal";
        user = "root";
        extraOptions.IdentityFile = "~/.ssh/root_home.pub";
      };
      "proxmox2-terraform" = {
        hostname = "proxmox2.servers.internal";
        user = "terraform";
        extraOptions.IdentityFile = "~/.ssh/admin_poop_systems.pub";
      };
      "proxmox3" = {
        hostname = "proxmox3.servers.internal";
        user = "root";
        extraOptions.IdentityFile = "~/.ssh/root_home.pub";
      };
      "proxmox3-terraform" = {
        hostname = "proxmox3.servers.internal";
        user = "terraform";
        extraOptions.IdentityFile = "~/.ssh/admin_poop_systems.pub";
      };
      "proxmox4" = {
        hostname = "proxmox4.servers.internal";
        user = "root";
        extraOptions.IdentityFile = "~/.ssh/root_home.pub";
      };
      "proxmox4-terraform" = {
        hostname = "proxmox4.servers.internal";
        user = "terraform";
        extraOptions.IdentityFile = "~/.ssh/admin_poop_systems.pub";
      };
      "proxmox5" = {
        hostname = "proxmox5.servers.internal";
        user = "root";
        extraOptions.IdentityFile = "~/.ssh/root_home.pub";
      };
      "proxmox5-terraform" = {
        hostname = "proxmox5.servers.internal";
        user = "terraform";
        extraOptions.IdentityFile = "~/.ssh/admin_poop_systems.pub";
      };
      "proxmox6" = {
        hostname = "proxmox6.servers.internal";
        user = "root";
        extraOptions.IdentityFile = "~/.ssh/root_home.pub";
      };
      "proxmox6-terraform" = {
        hostname = "proxmox6.servers.internal";
        user = "terraform";
        extraOptions.IdentityFile = "~/.ssh/admin_poop_systems.pub";
      };

      # ── Proxmox VMs ────────────────────────────────────────────────────────

      # ── UCG Fiber ───────────────────────────────────────────────────────────
      "ucg" = {
        hostname = "10.10.10.1";
        user = "root";
        extraOptions.IdentityFile = "~/.ssh/root_home.pub";
      };

      # ── DNS Servers ─────────────────────────────────────────────────────────
      "dns01" = {
        hostname = "10.10.10.53";
        user = "rpi";
        extraOptions.IdentityFile = "~/.ssh/root_home.pub";
      };
      "dns02" = {
        hostname = "10.10.10.54";
        user = "rpi";
        extraOptions.IdentityFile = "~/.ssh/root_home.pub";
      };
      "dns03" = {
        hostname = "10.10.10.194";
        user = "rpi";
        extraOptions.IdentityFile = "~/.ssh/root_home.pub";
      };
      "dns04" = {
        hostname = "10.10.10.200";
        user = "rpi";
        extraOptions.IdentityFile = "~/.ssh/root_home.pub";
      };

      "ns1 10.10.10.190" = {
        hostname = "10.10.10.190";
        user = "root";
        extraOptions.IdentityFile = "~/.ssh/root_home.pub";
      };

      # ── NixOS Workstation ───────────────────────────────────────────────────
      "nixos" = {
        hostname = "10.10.10.14";
        user = "donald";
        extraOptions.IdentityFile = "~/.ssh/donald.pub";
      };

      # ── GitHub ──────────────────────────────────────────────────────────────
      "github.com" = {
        user = "git";
        extraOptions.IdentityFile = "~/.ssh/github.pub";
      };

      # ── Forgejo (fartlab) ───────────────────────────────────────────────────
      "git.fartlab.dev" = {
        user = "git";
        extraOptions.IdentityFile = "~/.ssh/donald.pub";
      };
      # ── r740a (fartlab) ───────────────────────────────────────────────────
      "r740a 10.10.11.20" = {
        hostname = "10.10.11.20";
        user = "root";
        extraOptions.IdentityFile = "~/.ssh/root_home.pub";
      };
      # ── r640 (fartlab) ───────────────────────────────────────────────────
      "r640a 10.10.11.21" = {
        hostname = "10.10.11.21";
        user = "root";
        extraOptions.IdentityFile = "~/.ssh/root_home.pub";
      };
      # ── beelink01 (fartlab) ───────────────────────────────────────────────────
      "beelink01 10.10.11.30" = {
        hostname = "10.10.11.30";
        user = "root";
        extraOptions.IdentityFile = "~/.ssh/root_home.pub";
      };
      # ── beelink02 (fartlab) ───────────────────────────────────────────────────
      "beelink02 10.10.11.31" = {
        hostname = "10.10.11.31";
        user = "root";
        extraOptions.IdentityFile = "~/.ssh/root_home.pub";
      };
      # ── beelink03 (fartlab) ───────────────────────────────────────────────────
      "beelink03 10.10.11.32" = {
        hostname = "10.10.11.32";
        user = "root";
        extraOptions.IdentityFile = "~/.ssh/root_home.pub";
      };
    };
  };
}

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
    matchBlocks = {
      "*" = {
        extraOptions = {
          IdentityAgent = agentSocket;
        };
      };

      # ── Proxmox Servers ────────────────────────────────────────────────────
      "proxmox1" = {
        hostname = "proxmox1.servers.internal";
        user = "root";
        extraOptions.IdentityFile = "~/.ssh/root_home";
      };
      "proxmox1-terraform" = {
        hostname = "proxmox1.servers.internal";
        user = "terraform";
        extraOptions.IdentityFile = "~/.ssh/admin_poop_systems";
      };
      "proxmox2" = {
        hostname = "proxmox2.servers.internal";
        user = "root";
        extraOptions.IdentityFile = "~/.ssh/root_home";
      };
      "proxmox2-terraform" = {
        hostname = "proxmox2.servers.internal";
        user = "terraform";
        extraOptions.IdentityFile = "~/.ssh/admin_poop_systems";
      };
      "proxmox3" = {
        hostname = "proxmox3.servers.internal";
        user = "root";
        extraOptions.IdentityFile = "~/.ssh/root_home";
      };
      "proxmox3-terraform" = {
        hostname = "proxmox3.servers.internal";
        user = "terraform";
        extraOptions.IdentityFile = "~/.ssh/admin_poop_systems";
      };
      "proxmox4" = {
        hostname = "proxmox4.servers.internal";
        user = "root";
        extraOptions.IdentityFile = "~/.ssh/root_home";
      };
      "proxmox4-terraform" = {
        hostname = "proxmox4.servers.internal";
        user = "terraform";
        extraOptions.IdentityFile = "~/.ssh/admin_poop_systems";
      };
      "proxmox5" = {
        hostname = "proxmox5.servers.internal";
        user = "root";
        extraOptions.IdentityFile = "~/.ssh/root_home";
      };
      "proxmox5-terraform" = {
        hostname = "proxmox5.servers.internal";
        user = "terraform";
        extraOptions.IdentityFile = "~/.ssh/admin_poop_systems";
      };

      # ── Proxmox VMs ────────────────────────────────────────────────────────
      "k3s" = {
        hostname = "k3s.fatman.servers.internal";
        user = "donald";
        extraOptions.IdentityFile = "~/.ssh/root_home";
      };
      "asss" = {
        hostname = "asss.servers.internal";
        user = "donald";
        extraOptions.IdentityFile = "~/.ssh/root_home";
      };
      "gitea.fartlab.dev" = {
        user = "git";
        port = 2222;
      };

      # ── UCG Fiber ───────────────────────────────────────────────────────────
      "ucg" = {
        hostname = "10.10.10.1";
        user = "root";
        extraOptions.IdentityFile = "~/.ssh/root_home";
      };

      # ── DNS Servers ─────────────────────────────────────────────────────────
      "dns01" = {
        hostname = "10.10.10.53";
        user = "rpi";
        extraOptions.IdentityFile = "~/.ssh/root_home";
      };
      "dns02" = {
        hostname = "10.10.10.54";
        user = "rpi";
        extraOptions.IdentityFile = "~/.ssh/root_home";
      };
      "dns03" = {
        hostname = "10.10.10.194";
        user = "rpi";
        extraOptions.IdentityFile = "~/.ssh/root_home";
      };
      "dns04" = {
        hostname = "10.10.10.200";
        user = "rpi";
        extraOptions.IdentityFile = "~/.ssh/root_home";
      };

      # ── Home Assistant ──────────────────────────────────────────────────────
      "hass" = {
        hostname = "10.10.10.161";
        user = "root";
        extraOptions.IdentityFile = "~/.ssh/fatman";
      };

      # ── Claude Ops ──────────────────────────────────────────────────────────
      "donald3" = {
        hostname = "localhost";
        port = 2222;
        user = "user";
        extraOptions.IdentityFile = "~/.ssh/root_home";
      };
      "fc-test" = {
        hostname = "10.10.11.33";
        user = "donald";
        extraOptions.IdentityFile = "~/.ssh/root_home";
      };
      "remote-claude" = {
        hostname = "10.10.11.197";
        user = "donald";
        extraOptions.IdentityFile = "~/.ssh/root_home";
      };
      "stoat" = {
        hostname = "10.10.11.143";
        user = "donald";
        extraOptions.IdentityFile = "~/.ssh/root_home";
      };

      # ── NixOS Workstation ───────────────────────────────────────────────────
      "nixos" = {
        hostname = "10.10.10.14";
        user = "donald";
        extraOptions.IdentityFile = "~/.ssh/donald";
      };
    };
  };
}

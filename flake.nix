{
  description = "Donald's multi-platform Nix configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager-stable = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };

    _1password-shell-plugins = {
      url = "github:1Password/shell-plugins";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Trial — see INV-0002. Pinned to a release tag, so `nix flake update herdr`
    # on its own never moves it: bump the tag here, then run that to re-lock.
    # Builds from source (rust); nixpkgs has herdr too but lags (0.7.5 in 26.11).
    # (repo moved ogulcancelik/herdr → herdrdev/herdr; Apache-2.0 since 0.8.0)
    herdr = {
      url = "github:herdrdev/herdr/v0.9.5";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-overlay.follows = "rust-overlay";
    };

    # Only herdr's build toolchain. Top-level so it moves with `nix flake
    # update` / Renovate instead of staying at whatever herdr's tag locked
    # (an old copy used the deprecated stdenv.isLinux / isDarwin).
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # SBOMs of the running system (`just sbom`). Upstream flake, not nixpkgs:
    # nixpkgs-unstable's sbomnix fails to build (typepy 2 vs sqliteschema) and
    # 26.05's 1.7.6 can't read names/versions of structuredAttrs packages,
    # dropping ~60% of versions. Deliberately does NOT follow nixpkgs, for the
    # same reason. Tag-pinned: Renovate's nix manager proposes new tags.
    sbomnix.url = "github:tiiuae/sbomnix/v1.9.0";

    lazyvim-nix = {
      url = "github:pfassina/lazyvim-nix/a88c488cfd96e1d4274d34d2e35ddbe99dbe5757";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-stable,
      nix-darwin,
      home-manager,
      home-manager-stable,
      ...
    }@inputs:
    {

      # ── NixOS (workstation) ─────────────────────────────────────────────────
      nixosConfigurations.workstation = nixpkgs-stable.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/workstation/configuration.nix
          ./hosts/workstation/hardware-configuration.nix

          home-manager-stable.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.donald = import ./home/linux.nix;
            home-manager.backupFileExtension = "bak";
            home-manager.extraSpecialArgs = { inherit inputs; };
          }
        ];
      };

      # ── macOS (macbook) ─────────────────────────────────────────────────────
      # Replace YOUR-HOSTNAME with: scutil --get LocalHostName
      darwinConfigurations."donald-mbp" = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/macbook/darwin.nix

          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.donaldgifford = import ./home/darwin.nix;
            home-manager.backupFileExtension = "bak";
            home-manager.extraSpecialArgs = { inherit inputs; };
          }
        ];
      };
    };
}

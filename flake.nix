{
  description = "Donald's multi-platform Nix configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.11";

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager-stable = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs-stable";
    };

    _1password-shell-plugins.url = "github:1Password/shell-plugins";

    hunk = {
      url = "github:modem-dev/hunk";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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

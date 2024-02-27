{
  description = "NixOS WSL";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    flake-utils.url = "github:numtide/flake-utils";
    home-manager = {
      url = "github:nix-community/home-manager/release-23.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    vscode-server.url = "github:nix-community/nixos-vscode-server";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    home-manager,
    flake-utils,
    vscode-server,
    ...
  }:
    with nixpkgs.lib;
      {
        nixosModules.wsl = {
          imports = [
            ./modules

            (_: {
              wsl.version.rev = mkIf (self ? rev) self.rev;
            })
          ];
        };
        nixosModules.default = self.nixosModules.wsl;

        nixosConfigurations = let
          initialConfig = {config, ...}: {
            wsl.enable = true;

            programs.bash.loginShellInit = "nixos-wsl-welcome";

            system.stateVersion = config.system.nixos.release;
          };
        in {
          modern = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              self.nixosModules.default
              initialConfig
              home-manager.nixosModules.home-manager
              {
                home-manager = {
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  users.niksi = import ./modules/user.nix;
                  extraSpecialArgs = {inherit vscode-server;};
                };
              }
            ];
          };
        };
      }
      // flake-utils.lib.eachSystem
      ["x86_64-linux" "aarch64-linux"]
      (
        system: let
          pkgs = import nixpkgs {inherit system;};
        in {
          checks = let
            args = {inherit inputs;};
          in {
            dotnet-format = pkgs.callPackage ./checks/dotnet-format.nix args;
            nixpkgs-fmt = pkgs.callPackage ./checks/alejandra.nix args;
            shfmt = pkgs.callPackage ./checks/shfmt.nix args;
            rustfmt = pkgs.callPackage ./checks/rustfmt.nix args;
            side-effects = pkgs.callPackage ./checks/side-effects.nix args;
            username = pkgs.callPackage ./checks/username.nix args;
            test-native-utils = self.packages.${system}.utils;
          };

          packages = {
            utils = pkgs.callPackage ./utils {};
            staticUtils = pkgs.pkgsStatic.callPackage ./utils {};
            docs = pkgs.callPackage ./docs {};
          };

          devShells.default = pkgs.mkShell {
            RUST_SRC_PATH = "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}";

            nativeBuildInputs = with pkgs; [
              cargo
              clippy
              mdbook
              alejandra
              rustc
              rustfmt
              shfmt
            ];
          };
        }
      );
}

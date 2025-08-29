{
  description = "Full-stack Rust (Axum backend) + React (frontend) separate build";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, rust-overlay, ... }:
    let
      system = "x86_64-linux";
      overlays = [ rust-overlay.overlays.default ];
      pkgs = import nixpkgs { inherit system overlays; };

      rust = pkgs.rust-bin.stable.latest.default;
    in
    {
      packages.${system} = rec {
        # Backend package (Axum)
        backend = pkgs.rustPlatform.buildRustPackage {
          pname = "backend";
          version = "0.1.0";
          src = ./backend;
          cargoLock.lockFile = ./backend/Cargo.lock;
          cargoBuildOptions = [ "-p" "backend" ];

          # No frontend copy, fully separate
        };

        # Frontend package (React via Node/Nix)
        frontend = pkgs.stdenv.mkDerivation {
          pname = "frontend";
          version = "0.1.0";
          src = ./frontend;

          nativeBuildInputs = [
            pkgs.nodejs
            pkgs.yarn
          ];

          buildPhase = ''
            yarn install
            yarn build
          '';

          installPhase = ''
            mkdir -p $out
            cp -r build/* $out/
          '';
        };

        # Combined default package (optional)
        default = pkgs.symlinkJoin {
          name = "fullstack-app";
          paths = [ backend frontend ];
        };
      };

      # Dev shells
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [
          rust
          pkgs.nodejs
          pkgs.yarn
        ];
      };

      # Apps for `nix run .#frontend` / `nix run .#backend`
      apps.${system} = rec {
        backend = {
          type = "app";
          program = "${self.packages.${system}.backend}/bin/backend";
        };

        frontend = {
          type = "app";
          program = "${pkgs.writeShellScript "frontend-dev" ''
            cd ${./frontend}
            yarn dev
          ''}";
        };
      };
    };
}


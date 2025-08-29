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
        # -----------------
        # Backend: Axum
        # -----------------
        backend = pkgs.rustPlatform.buildRustPackage {
          pname = "backend";
          version = "0.1.0";
          src = ./backend;
          cargoLock.lockFile = ./backend/Cargo.lock;
          cargoBuildOptions = [ "-p" "backend" ];
        };

        # -----------------
        # Frontend: React + Vite
        # -----------------
        frontend = pkgs.stdenv.mkDerivation {
          pname = "frontend";
          version = "0.1.0";
          src = ./frontend;

          nativeBuildInputs = [
            pkgs.nodejs
            pkgs.yarn
          ];

          buildPhase = ''
            export PATH=$PATH:${pkgs.yarn}/bin
            yarn install
            yarn build
          '';

          installPhase = ''
            mkdir -p $out
            cp -r build/* $out/
          '';
        };

        # -----------------
        # Optional combined package
        # -----------------
        default = pkgs.symlinkJoin {
          name = "fullstack-app";
          paths = [ backend frontend ];
        };
      };

      # -----------------
      # Dev shell
      # -----------------
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [
          rust
          pkgs.nodejs
          pkgs.yarn
        ];

        shellHook = ''
          export PATH=$PATH:${pkgs.yarn}/bin
        '';
      };

      # -----------------
      # Apps for nix run
      # -----------------
      apps.${system} = rec {
        backend = {
          type = "app";
          program = "${self.packages.${system}.backend}/bin/backend";
        };

        frontend = {
          type = "app";
          program = "${pkgs.writeShellScript "frontend-dev" ''
            export PATH=$PATH:${pkgs.yarn}/bin
            cd ${./frontend}
            yarn dev
          ''}";
        };
      };
    };
}


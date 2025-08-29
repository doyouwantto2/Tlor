{
  description = "Full-stack React + Axum Rust app with Nix flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    oxalica.url = "github:oxalica/rust-overlay";
    oxalica.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, oxalica, ... }:
    let
      system = "x86_64-linux";
      overlays = [ oxalica.overlays.default ];
      pkgs = import nixpkgs { inherit system overlays; };

      rust = pkgs.rust-bin.stable.latest.default;
      nodejs = pkgs.nodejs; # Node for React
    in
    {
      packages.${system} = rec {
        # ----------------------
        # Backend: Rust/Axum
        # ----------------------
        backend = pkgs.rustPlatform.buildRustPackage {
          pname = "backend";
          version = "0.1.0";
          src = ./backend;
          cargoLock.lockFile = ./backend/Cargo.lock;

          cargoBuildOptions = [ "-p" "backend" ];
        };

        # ----------------------
        # Frontend: React
        # ----------------------
        frontend = pkgs.stdenv.mkDerivation {
          pname = "frontend";
          version = "0.1.0";
          src = ./frontend;

          nativeBuildInputs = [ nodejs ];

          buildPhase = ''
            npm install
            npm run build
          '';

          installPhase = ''
            mkdir -p $out
            cp -r dist/* $out/
          '';
        };

        # ----------------------
        # Fullstack combined
        # ----------------------
        default = pkgs.symlinkJoin {
          name = "fullstack-app";
          paths = [ backend frontend ];
        };
      };

      # ----------------------
      # Apps for `nix run .#foo`
      # ----------------------
      apps.${system} = rec {
        backend = {
          type = "app";
          program = "${self.packages.${system}.backend}/bin/backend";
        };

        frontend = {
          type = "app";
          program = "${pkgs.writeShellScript "run-frontend" ''
            export PATH=${nodejs}/bin:$PATH
            cd ${./frontend}
            npm run dev
          ''}";
        };

        default = {
          type = "app";
          program = "${pkgs.writeShellScript "run-fullstack" ''
            export PATH=${rust}/bin:${nodejs}/bin:$PATH

            echo "🚀 Starting backend..."
            ${self.packages.${system}.backend}/bin/backend &
            BACK_PID=$!

            echo "🌐 Starting frontend..."
            cd ${./frontend}
            npm run dev

            # Forward Ctrl+C
            trap "kill $BACK_PID; exit 0" SIGINT SIGTERM
            wait
          ''}";
        };
      };

      # ----------------------
      # Dev shell
      # ----------------------
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [ rust nodejs ];
      };
    };
}


{
  description = "Full-stack Rust (Axum) + React (Vite)";

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
      nodejs = pkgs.nodejs; # Node for frontend (React + Vite)
    in
    {
      packages.${system} = rec {
        # ---------------------
        # Backend (Axum)
        # ---------------------
        backend = pkgs.rustPlatform.buildRustPackage {
          pname = "backend";
          version = "0.1.0";
          src = ./backend;
          cargoLock.lockFile = ./backend/Cargo.lock;

          cargoBuildOptions = [ "-p" "backend" ];

          postInstall = ''
            mkdir -p $out/share/frontend
            cp -r ../frontend/dist/* $out/share/frontend
          '';
        };

        # ---------------------
        # Full-stack wrapper
        # ---------------------
        default = pkgs.symlinkJoin {
          name = "fullstack-app";
          paths = [ backend ];
        };
      };

      # -------------------
      # Apps
      # -------------------
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
            npx vite
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
            npx vite

            trap "kill $BACK_PID; exit 0" SIGINT SIGTERM
            wait
          ''}";
        };
      };

      # -------------------
      # Dev shell
      # -------------------
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [
          rust
          nodejs
        ];
      };
    };
}


{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self, nixpkgs, flake-utils, pyproject-nix, uv2nix, pyproject-build-systems,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system:
    let
      inherit (nixpkgs) lib;
      pkgs = import nixpkgs { inherit system; };
      python = pkgs.python312;

      workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };
      overlay = workspace.mkPyprojectOverlay {
        sourcePreference = "wheel";
      };
      hacks = pkgs.callPackage pyproject-nix.build.hacks {};

      pyprojectOverrides = final: prev: {
      };

      pythonSet =
        (pkgs.callPackage pyproject-nix.build.packages {
          inherit python;
        }).overrideScope (
          lib.composeManyExtensions [
            pyproject-build-systems.overlays.default
            overlay
            pyprojectOverrides
          ]
        );

      inherit (pkgs.callPackages pyproject-nix.build.util { }) mkApplication;

    in {
      packages = {
        ssmm-patcher = mkApplication {
          venv = pythonSet.mkVirtualEnv "application-env" workspace.deps.default;
          package = pythonSet.ssmm-patcher;
        };
        default = self.packages.${system}.ssmm-patcher;
      };
      devShells.uv = pkgs.mkShell {
        packages = [
          pkgs.uv
        ];
      };
    });
}
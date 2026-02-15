{
  description = "Nix module for installing .NET SDKs with specific versions and workloads from global.json";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nix-unit.url = "github:nix-community/nix-unit";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    nix-unit,
  }:
    flake-utils.lib.eachDefaultSystem
    (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
        dotnet = import ./src/nix-dotnet.nix {inherit pkgs;};
      in {
        lib = dotnet;
        packages = {
          basic-example = dotnet.mkDotnet {
            globalJsonPath = ./global.json;
            workloads = [];
            outputHash =
              if system == "aarch64-darwin"
              then "sha256-k7etFSnLiKFSKn5zVhp9Oom2yPRIAlkY/fKmwUG0pBI="
              else null; # Compute on each target system (e.g., nix build .#basic-example)
          };

          workload-example = dotnet.mkDotnet {
            globalJsonPath = ./global.json;
            workloads = ["android"];
            outputHash =
              if system == "aarch64-darwin"
              then "sha256-xbWrAYckiJF4xhbsXvCJL3gLrcLXcIxrlsHwM7tGdGU="
              else null; # Compute on each target system (e.g., nix build .#workload-example)
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            alejandra
            nil
            nix-unit.packages.${system}.default
          ];
        };

        checks = {
          fmt =
            pkgs.runCommand "check-fmt"
            {
              buildInputs = [pkgs.alejandra];
            } "
              alejandra --check ${./.}
              touch $out
            ";

          unit-tests =
            pkgs.runCommand "unit-tests" {}
            ''
              ${pkgs.nix}/bin/nix-instantiate --eval --strict ${./tests/unit.nix} \
                --arg lib "import ${./src/lib.nix} { pkgs = import ${nixpkgs} { system = \"${system}\"; }; }" 2>&1 | tee $out
              echo "All tests evaluate successfully" >> $out
            '';

          integration-test = import ./tests/integration-test.nix {
            inherit pkgs dotnet;
          };
        };
      }
    )
    // {
      templates = {
        default = {
          path = ./examples/basic;
          description = "Basic nix-dotnet example";
        };
        with-workloads = {
          path = ./examples/with-workloads;
          description = "Example with .NET workloads";
        };
      };

      tests = import ./tests/unit.nix {
        lib = import ./src/lib.nix {pkgs = nixpkgs.legacyPackages.x86_64-linux;};
      };
    };
}

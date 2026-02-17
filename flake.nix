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
        unitTests = import ./tests/unit.nix {
          lib = dotnet.internal;
          inherit dotnet;
        };

        unitTestAssertions =
          builtins.map
          (
            name: let
              test = unitTests.${name};
            in
              if test.expr == test.expected
              then true
              else throw "Unit test failed: ${name}"
          )
          (builtins.attrNames unitTests);
      in {
        lib = dotnet;
        packages = {
          basic-example = dotnet.mkDotnet {
            globalJsonPath = ./global.json;
            workloads = [];
            outputHash =
              if system == "aarch64-darwin"
              then "sha256-k7etFSnLiKFSKn5zVhp9Oom2yPRIAlkY/fKmwUG0pBI="
              else if system == "x86_64-linux"
              then "sha256-zavpTqfPO/x1YFvGww+QBzyK70eGi50TaA5wkaGziFg="
              else null; # Compute on each target system (e.g., nix build .#basic-example)
          };

          workload-example = dotnet.mkDotnet {
            globalJsonPath = ./global.json;
            workloads = ["android"];
            outputHash =
              if system == "aarch64-darwin"
              then "sha256-xbWrAYckiJF4xhbsXvCJL3gLrcLXcIxrlsHwM7tGdGU="
              else if system == "x86_64-linux"
              then "sha256-R6+gCgcfrTv1NYQyI0/3YXmjDRvvooPEOjCR59WSpfk="
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

          unit-tests = builtins.deepSeq unitTestAssertions (pkgs.runCommand "unit-tests" {} ''
            echo "${toString (builtins.length (builtins.attrNames unitTests))} unit tests passed" > $out
          '');

          integration-test = import ./tests/integration-test.nix {
            inherit pkgs dotnet;
          };

          integration-workload-test = import ./tests/integration-workload-test.nix {
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

      tests = let
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        dotnet = import ./src/nix-dotnet.nix {inherit pkgs;};
      in
        import ./tests/unit.nix {
          lib = dotnet.internal;
          inherit dotnet;
        };
    };
}

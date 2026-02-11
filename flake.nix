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
        hashCachePath = ./sdk-hashes.json;
        dotnet = import ./src/nix-dotnet.nix {inherit pkgs hashCachePath;};
      in {
        lib = dotnet;

        packages =
          {
            prefetch-sdk = pkgs.writeShellScriptBin "prefetch-sdk" ''
              set -euo pipefail

              version="''${1:-}"
              platform="''${2:-linux}"
              arch="''${3:-x64}"

              if [ -z "$version" ]; then
                echo "Usage: prefetch-sdk <sdk-version> [platform] [arch]"
                echo "  platform: linux, osx (default: linux)"
                echo "  arch: x64, arm64 (default: x64)"
                echo "Example: prefetch-sdk 10.0.103"
                echo "Example: prefetch-sdk 10.0.103 osx arm64"
                exit 1
              fi

              cache_key="''${platform}-''${arch}"
              url="https://builds.dotnet.microsoft.com/dotnet/Sdk/$version/dotnet-sdk-$version-$platform-$arch.tar.gz"

              echo "Fetching hash for .NET SDK $version..."
              echo "URL: $url"

              hash=$(${pkgs.nix}/bin/nix-prefetch-url "$url" 2>&1 | tail -1)

              echo "Got hash: $hash"
              echo ""
              echo "Add this to sdk-hashes.json under \"$version\":"
              echo "  \"$cache_key\": \"$hash\""
            '';
          }
          // pkgs.lib.optionalAttrs (builtins.elem system ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"]) {
            basic-example = dotnet.mkDotnet {
              globalJsonPath = ./global.json;
              workloads = [];
            };

            workload-example = dotnet.mkDotnet {
              globalJsonPath = ./global.json;
              workloads = ["android"];
            };
          };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            alejandra
            nil
            nix-unit.packages.${system}.default
          ];
        };

        checks =
          {
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
                  --arg lib "import ${./src/lib.nix} { pkgs = import ${nixpkgs} { system = \"${system}\"; }; hashCachePath = ${./sdk-hashes.json}; }" 2>&1 | tee $out
                echo "All tests evaluate successfully" >> $out
              '';
          }
          // pkgs.lib.optionalAttrs (builtins.elem system ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"]) {
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
        lib = import ./src/lib.nix {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          hashCachePath = ./sdk-hashes.json;
        };
      };
    };
}

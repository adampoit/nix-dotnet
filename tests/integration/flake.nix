{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem
    (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      dotnet = import ../../src/nix-dotnet.nix {inherit pkgs;};
      sdkOutputHash =
        if system == "aarch64-darwin"
        then "sha256-YxvVtFxTcXR982ar15JUpKhv05WQ4AE4+xH1wxk3yz4="
        else if system == "x86_64-linux"
        then "sha256-kp0avinB5M1ZpWbdBBArpdsMVdRXqDX3FPF2lSBnWt0="
        else throw "No outputHash configured for system ${system}";

      dotnetSdk = dotnet.mkDotnet {
        globalJsonPath = ./global.json;
        workloads = [];
        outputHash = sdkOutputHash;
      };
    in {
      packages.integration-test = pkgs.stdenv.mkDerivation {
        pname = "dotnet-nix-integration-test";
        version = "1.0.0";

        src = ./.;

        nativeBuildInputs = [
          pkgs.cacert
          dotnetSdk
        ];

        buildPhase = ''
          runHook preBuild

          # Use absolute paths for .NET CLI environment
          export DOTNET_CLI_HOME="$PWD/.dotnet-cli-home"
          export NUGET_PACKAGES="$PWD/.nuget/packages"
          export NUGET_HTTP_CACHE_PATH="$PWD/.nuget/http-cache"
          export HOME="$PWD/.home"

          mkdir -p "$DOTNET_CLI_HOME" "$NUGET_PACKAGES" "$NUGET_HTTP_CACHE_PATH" "$HOME"

          echo "=== Integration Test: Building .NET Project ==="
          echo "SDK Version: $(dotnet --version)"
          echo ""

          # Restore NuGet packages
          echo "Step 1: Restoring NuGet packages..."
          dotnet restore TestSolution.slnx --locked-mode

          # Build the solution
          echo ""
          echo "Step 2: Building solution..."
          dotnet build TestSolution.slnx --configuration Release --no-restore

          # Run the tests
          echo ""
          echo "Step 3: Running tests..."
          dotnet test TestApp.Tests/TestApp.Tests.csproj \
            --configuration Release \
            --no-build \
            --verbosity normal

          echo ""
          echo "=== Integration Test Passed ==="

          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall

          mkdir -p $out
          echo "Integration test completed successfully" > $out/result

          runHook postInstall
        '';

        meta = {
          description = "Integration test for nix-dotnet module";
        };
      };

      packages.default = self.packages.${system}.integration-test;
      checks.integration-test = self.packages.${system}.integration-test;
    });
}

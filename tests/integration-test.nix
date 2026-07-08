{
  pkgs,
  dotnet,
  outputHash,
}: let
  dotnetSdk = dotnet.mkDotnet {
    globalJsonPath = ./integration/global.json;
    workloads = [];
    inherit outputHash;
  };
in
  pkgs.stdenv.mkDerivation {
    pname = "dotnet-nix-integration-test";
    version = "1.0.0";

    src = ./integration;

    nativeBuildInputs = [
      pkgs.cacert
      dotnetSdk
    ];

    buildPhase = ''
      runHook preBuild

      # Use absolute paths for NuGet caches while relying on mkDotnet's setup hook for DOTNET_CLI_HOME.
      export NUGET_PACKAGES="$PWD/.nuget/packages"
      export NUGET_HTTP_CACHE_PATH="$PWD/.nuget/http-cache"

      mkdir -p "$NUGET_PACKAGES" "$NUGET_HTTP_CACHE_PATH"

      echo "=== Integration Test: Building .NET Project ==="
      echo "dotnet on PATH: $(command -v dotnet)"
      echo "DOTNET_ROOT: $DOTNET_ROOT"
      echo "SDK Version: $(dotnet --version)"
      echo ""

      if [ "$(command -v dotnet)" != "${dotnetSdk}/bin/dotnet" ]; then
        echo "ERROR: dotnet did not resolve to the mkDotnet package"
        exit 1
      fi

      if [ "$DOTNET_ROOT" != "${dotnetSdk}" ]; then
        echo "ERROR: DOTNET_ROOT was not exported by the setup hook"
        exit 1
      fi

      if [ -z "''${DOTNET_CLI_HOME:-}" ] || [ ! -d "$DOTNET_CLI_HOME" ]; then
        echo "ERROR: DOTNET_CLI_HOME was not created by the setup hook"
        exit 1
      fi

      if [ "''${DOTNET_CLI_TELEMETRY_OPTOUT:-}" != "1" ] || [ "''${DOTNET_NOLOGO:-}" != "1" ]; then
        echo "ERROR: reproducibility-friendly .NET defaults were not exported by the setup hook"
        exit 1
      fi

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
  }

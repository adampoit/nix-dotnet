{
  pkgs,
  dotnet,
  outputHash,
}: let
  dotnetSdk = dotnet.mkDotnet {
    globalJsonPath = ./integration/global.json;
    additionalSdks = [
      {
        sdkVersion = "9.0.304";
      }
    ];
    inherit outputHash;
  };
in
  pkgs.stdenv.mkDerivation {
    pname = "dotnet-nix-integration-multi-sdk-test";
    version = "1.0.0";

    src = ./integration;

    nativeBuildInputs = [
      pkgs.cacert
      pkgs.gnugrep
    ];

    DOTNET_ROOT = "${dotnetSdk}";

    buildPhase = ''
      runHook preBuild

      export PATH="${dotnetSdk}:$PATH"

      export DOTNET_CLI_HOME="$PWD/.dotnet-cli-home"
      export NUGET_PACKAGES="$PWD/.nuget/packages"
      export NUGET_HTTP_CACHE_PATH="$PWD/.nuget/http-cache"
      export HOME="$PWD/.home"

      mkdir -p "$DOTNET_CLI_HOME" "$NUGET_PACKAGES" "$NUGET_HTTP_CACHE_PATH" "$HOME"

      echo "=== Integration Test: Multiple SDKs In One dotnet ==="
      echo "SDK Version: $(dotnet --version)"
      echo ""

      echo "Step 1: Verifying available SDK versions..."
      sdk_list="$(dotnet --list-sdks)"
      echo "$sdk_list"

      if ! printf '%s\n' "$sdk_list" | grep -qE '^10\.0\.103[[:space:]]'; then
        echo "ERROR: 10.0.103 SDK is missing"
        exit 1
      fi

      if ! printf '%s\n' "$sdk_list" | grep -qE '^9\.0\.304[[:space:]]'; then
        echo "ERROR: 9.0.304 SDK is missing"
        exit 1
      fi

      echo ""
      echo "Step 2: Restoring NuGet packages in locked mode..."
      dotnet restore TestSolution.slnx --locked-mode

      echo ""
      echo "Step 3: Building solution..."
      dotnet build TestSolution.slnx --configuration Release --no-restore

      echo ""
      echo "Step 4: Running tests..."
      dotnet test TestApp.Tests/TestApp.Tests.csproj \
        --configuration Release \
        --no-build \
        --verbosity normal

      echo ""
      echo "=== Integration Multi-SDK Test Passed ==="

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out
      echo "Integration multi-sdk test completed successfully" > $out/result

      runHook postInstall
    '';
  }

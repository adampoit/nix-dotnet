{
  pkgs,
  hashCachePath ? ../sdk-hashes.json,
}: let
  lib = import ./lib.nix {inherit pkgs hashCachePath;};

  inherit
    (lib)
    validateSdkVersion
    validateWorkload
    buildWorkloadNames
    buildWorkloadCommands
    sanitizePname
    readGlobalJson
    getSdkUrl
    getSdkHash
    ;

  mkDotnetSdk = {
    sdkVersion,
    workloads ? [],
  }: let
    validatedSdkVersion = validateSdkVersion sdkVersion;
    validatedWorkloads = map validateWorkload workloads;
    workloadNames = buildWorkloadNames validatedWorkloads;
    workloadCommands = buildWorkloadCommands validatedWorkloads;
  in
    pkgs.stdenv.mkDerivation {
      pname = sanitizePname "dotnet-sdk-${validatedSdkVersion}-${workloadNames}-packs";
      version = validatedSdkVersion;

      src = let
        arch =
          if pkgs.stdenv.isx86_64
          then "x64"
          else if pkgs.stdenv.isAarch64
          then "arm64"
          else throw "Unsupported architecture: only x86_64 and aarch64 are supported";
        sdkUrl = getSdkUrl validatedSdkVersion arch;
        sdkHash = getSdkHash validatedSdkVersion arch;
      in
        pkgs.fetchurl {
          url = sdkUrl;
          sha256 = sdkHash;
        };

      nativeBuildInputs = with pkgs; [
        gnutar
        patchelf
        cacert
      ];

      unpackPhase = ''
        runHook preUnpack
        mkdir -p "$out"
        tar -xzf "$src" -C "$out"
        runHook postUnpack
      '';

      dontConfigure = true;

      buildPhase = ''
        runHook preBuild

        if [ ! -f "$out/dotnet" ]; then
          echo "ERROR: dotnet executable not found after extraction"
          exit 1
        fi

        # Patch binaries before use (required for sandboxed builds)
        find "$out" -type f \( -executable -o -name "*.so" \) 2>/dev/null | while read f; do
          if patchelf --print-interpreter "$f" >/dev/null 2>&1; then
            INTERP="$(cat $NIX_CC/nix-support/dynamic-linker)"
            if ! patchelf --set-interpreter "$INTERP" "$f" 2>/dev/null; then
              echo "WARN: Failed to set interpreter for $f"
            fi
            if ! patchelf --set-rpath "${pkgs.stdenv.cc.cc.lib}/lib" "$f" 2>/dev/null; then
              echo "WARN: Failed to set rpath for $f"
            fi
          fi
        done

        export DOTNET_ROOT="$out"
        export PATH="$out:$PATH"
        export DOTNET_CLI_HOME="$out/.dotnet-cli-home"
        export NUGET_PACKAGES="$out/.nuget/packages"
        export NUGET_HTTP_CACHE_PATH="$out/.nuget/http-cache"
        export HOME="$out/.home"

        mkdir -p "$DOTNET_CLI_HOME" "$NUGET_PACKAGES" "$NUGET_HTTP_CACHE_PATH" "$HOME"

        ${workloadCommands}

        echo "Installation complete"
        echo "SDK Version: $($out/dotnet --version)"

        runHook postBuild
      '';

      passthru = {
        inherit sdkVersion workloads;
      };

      meta = with pkgs.lib; {
        description = ".NET SDK ${validatedSdkVersion} with workloads [${workloadNames}]";
        homepage = "https://dotnet.microsoft.com/";
        license = licenses.mit;
        maintainers = [];
        platforms = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
      };
    };

  mkDotnet = {
    globalJsonPath,
    workloads ? [],
  }: let
    globalConfig = readGlobalJson globalJsonPath;
    sdkVersion = globalConfig.sdkVersion;
    workloadVersion = globalConfig.workloadVersion;
    workloadObjects =
      map
      (name: {
        inherit name;
        version = workloadVersion;
      })
      workloads;
  in
    if sdkVersion == null
    then throw "Could not read SDK version from ${toString globalJsonPath}. Make sure the file exists and has a 'sdk.version' field."
    else
      mkDotnetSdk {
        inherit sdkVersion;
        workloads = workloadObjects;
      };
in {
  inherit mkDotnet;
  internal = lib;
}

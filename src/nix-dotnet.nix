{pkgs}: let
  lib = import ./lib.nix {inherit pkgs;};

  inherit
    (lib)
    validateSdkVersion
    validateWorkload
    buildWorkloadNames
    buildWorkloadCommands
    sanitizePname
    readGlobalJson
    ;

  defaultInstallScriptUrl = "https://dot.net/v1/dotnet-install.sh";
  defaultInstallScriptSha256 = "0hp4gjss641gabh24wf1xsxp9y1vb48fna5vc9ag24rp614nhahh";

  mkDotnetSdk = {
    sdkVersion,
    workloads ? [],
    installScriptUrl ? defaultInstallScriptUrl,
    installScriptSha256 ? defaultInstallScriptSha256,
  }: let
    validatedSdkVersion = validateSdkVersion sdkVersion;
    validatedWorkloads = map validateWorkload workloads;
    workloadNames = buildWorkloadNames validatedWorkloads;
    workloadCommands = buildWorkloadCommands validatedWorkloads;

    installScript = pkgs.fetchurl {
      url = installScriptUrl;
      sha256 = installScriptSha256;
    };
  in
    pkgs.stdenv.mkDerivation {
      pname = sanitizePname "dotnet-sdk-${validatedSdkVersion}-${workloadNames}-packs";
      version = validatedSdkVersion;

      src = null;
      dontUnpack = true;

      nativeBuildInputs = with pkgs; [
        unzip
        gnutar
        bash
        patchelf
        cacert
        curl
      ];

      buildPhase = ''
        runHook preBuild

        mkdir -p "$out"

        echo "Using verified dotnet-install script from ${installScriptUrl}"
        cp ${installScript} dotnet-install.sh
        chmod +x dotnet-install.sh

        echo "Installing .NET SDK ${validatedSdkVersion} into $out"
        bash ./dotnet-install.sh \
          --version "${validatedSdkVersion}" \
          --install-dir "$out" \
          --no-path

        if [ ! -f "$out/dotnet" ]; then
          echo "ERROR: dotnet executable not found after installation"
          exit 1
        fi
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

      fixupPhase = ''
        runHook preFixup

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

        runHook postFixup
      '';

      passthru = {
        inherit sdkVersion workloads;
      };

      meta = with pkgs.lib; {
        description = ".NET SDK ${validatedSdkVersion} with workloads [${workloadNames}]";
        homepage = "https://dotnet.microsoft.com/";
        license = licenses.mit;
        maintainers = [];
        platforms = platforms.all;
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

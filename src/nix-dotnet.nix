{pkgs}: let
  lib = import ./lib.nix {inherit pkgs;};

  inherit
    (lib)
    validateSdkVersion
    validateWorkload
    buildWorkloadNames
    buildWorkloadPnameSuffix
    buildWorkloadCommands
    sanitizePname
    validateOutputHash
    readGlobalJson
    ;

  defaultInstallScriptUrl = "https://raw.githubusercontent.com/dotnet/install-scripts/13cdf4607a097b262a91722458e860ea2162c838/src/dotnet-install.sh";
  defaultInstallScriptSha256 = "sha256-CC92heFWc4obLi7YOBpiGHDUzo6MWSeANFVvBcGG6y4=";
  dotnetLibraryPath = pkgs.lib.makeLibraryPath [pkgs.stdenv.cc.cc pkgs.zlib pkgs.icu pkgs.openssl];
  supportedPlatforms = [
    "x86_64-linux"
    "aarch64-linux"
    "x86_64-darwin"
    "aarch64-darwin"
  ];

  resolveOutputHash = outputHashes:
    validateOutputHash (
      if outputHashes == null
      then throw "outputHashes is required. Provide fixed-output hashes keyed by Nix system."
      else if builtins.hasAttr pkgs.stdenv.hostPlatform.system outputHashes
      then outputHashes.${pkgs.stdenv.hostPlatform.system}
      else throw "outputHashes is missing an entry for system '${pkgs.stdenv.hostPlatform.system}'."
    );

  buildDotnetModulePassthru = finalSdk: sdkVersion: let
    major = (lib.parseSdkVersion sdkVersion).major;
    sdkAttr = "sdk_${major}_0";
    dotnetCoreSdk = pkgs.dotnetCorePackages.${sdkAttr} or null;
  in {
    # buildDotnetModule adds `dotnet-sdk.packages` to buildInputs and links them
    # into the offline NuGet source via configureNuget. Our SDK only ships the
    # SDK itself; the reference packs and host runtime packs (as NuGet
    # derivations exposing share/nuget/source) come from the matching nixpkgs
    # SDK, which builds them from the same .NET major version.
    packages =
      if dotnetCoreSdk == null
      then [finalSdk]
      else dotnetCoreSdk.packages or [finalSdk];
    icu = pkgs.icu;
    targetPackages =
      if dotnetCoreSdk == null
      then {}
      else dotnetCoreSdk.targetPackages or {};
  };

  # The nixpkgs dotnet SDK setup hook provides the offline NuGet machinery
  # (addNugetInputs + configureNuget, registered in preConfigurePhases) that
  # buildDotnetModule relies on. It is parameterised by @lndir@ and @xmlstarlet@;
  # substitute those so we depend only on those two (light) tools rather than the
  # whole nixpkgs SDK closure.
  nugetSetupHook =
    pkgs.replaceVars
    (pkgs.path + "/pkgs/development/compilers/dotnet/dotnet-sdk-setup-hook.sh")
    {inherit (pkgs) lndir xmlstarlet;};

  setupHook = ''
    dotnetSdkRoot="$(cd "$(dirname "''${BASH_SOURCE[0]}")/.." && pwd)"
    export DOTNET_ROOT="$dotnetSdkRoot"

    # Dotnet expects a writable home directory for its configuration files.
    if [ ! -w "''${HOME:-}" ]; then
      export HOME="$(mktemp -d)"
    fi

    dotnetConfigureCliHome() {
      dotnetDefaultCliHome="$1"
      if [ -z "''${DOTNET_CLI_HOME:-}" ] || ! mkdir -p "$DOTNET_CLI_HOME" 2>/dev/null; then
        export DOTNET_CLI_HOME="$dotnetDefaultCliHome"
        mkdir -p "$DOTNET_CLI_HOME"
      fi
    }

    dotnetConfigureCliHome "''${TMPDIR:-/tmp}/dotnet-cli-home"

    export DOTNET_CLI_TELEMETRY_OPTOUT="''${DOTNET_CLI_TELEMETRY_OPTOUT:-1}"
    export DOTNET_NOLOGO="''${DOTNET_NOLOGO:-1}"
    export DOTNET_SKIP_FIRST_TIME_EXPERIENCE="''${DOTNET_SKIP_FIRST_TIME_EXPERIENCE:-1}"
    export DOTNET_SKIP_WORKLOAD_INTEGRITY_CHECK="''${DOTNET_SKIP_WORKLOAD_INTEGRITY_CHECK:-1}"
    export DOTNET_GENERATE_ASPNET_CERTIFICATE="''${DOTNET_GENERATE_ASPNET_CERTIFICATE:-0}"

    # Bring in the nixpkgs offline NuGet machinery (configureNuget, addNugetInputs)
    # so buildDotnetModule can restore without reaching nuget.org.
    source ${nugetSetupHook}

    shellHook="''${shellHook:-}
    if [ -z \"\''${DOTNET_CLI_HOME:-}\" ] || [[ \"\''${DOTNET_CLI_HOME}\" == /nix/var/nix/builds/* ]]; then
      export DOTNET_CLI_HOME=\"\''${PWD}/.dotnet-cli-home\"
      mkdir -p \"\''${DOTNET_CLI_HOME}\"
    fi
    "
  '';

  finalizeRawSdk = rawSdk:
    if pkgs.stdenv.isLinux
    then let
      finalSdk = pkgs.stdenv.mkDerivation {
        pname = rawSdk.pname;
        inherit (rawSdk) version;

        src = rawSdk;
        dontUnpack = true;

        nativeBuildInputs = [pkgs.patchelf];

        installPhase = ''
          runHook preInstall

          mkdir -p "$out"
          cp -a "$src" "$out/.runtime"
          chmod -R u+w "$out/.runtime"

          while IFS= read -r -d $'\0' file; do
            if patchelf --print-rpath "$file" >/dev/null 2>&1; then
              if patchelf --print-interpreter "$file" >/dev/null 2>&1; then
                patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" "$file"
              fi

              currentRpath="$(patchelf --print-rpath "$file" 2>/dev/null || true)"
              if [ -n "$currentRpath" ]; then
                patchelf --set-rpath "${dotnetLibraryPath}:$currentRpath" "$file"
              else
                patchelf --set-rpath "${dotnetLibraryPath}" "$file"
              fi
            fi
          done < <(find "$out/.runtime" -type f -print0)

          for entry in "$out/.runtime"/*; do
            name="$(basename "$entry")"
            if [ "$name" != "bin" ] && [ "$name" != "dotnet" ] && [ "$name" != "nix-support" ]; then
              ln -s ".runtime/$name" "$out/$name"
            fi
          done

          printf '%s\n' \
            '#!${pkgs.bash}/bin/bash' \
            'export LD_LIBRARY_PATH="${dotnetLibraryPath}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"' \
            'script_dir="$(cd "$(dirname "$0")" && pwd)"' \
            'export DOTNET_ROOT="$script_dir"' \
            'export DOTNET_CLI_HOME="''${DOTNET_CLI_HOME:-''${TMPDIR:-/tmp}/dotnet-cli-home}"' \
            'mkdir -p "$DOTNET_CLI_HOME"' \
            'export DOTNET_CLI_TELEMETRY_OPTOUT="''${DOTNET_CLI_TELEMETRY_OPTOUT:-1}"' \
            'export DOTNET_NOLOGO="''${DOTNET_NOLOGO:-1}"' \
            'export DOTNET_SKIP_FIRST_TIME_EXPERIENCE="''${DOTNET_SKIP_FIRST_TIME_EXPERIENCE:-1}"' \
            'export DOTNET_GENERATE_ASPNET_CERTIFICATE="''${DOTNET_GENERATE_ASPNET_CERTIFICATE:-0}"' \
            'exec "$script_dir/.runtime/dotnet" "$@"' \
            > "$out/dotnet"
          chmod +x "$out/dotnet"

          mkdir -p "$out/bin"
          printf '%s\n' \
            '#!${pkgs.bash}/bin/bash' \
            'sdk_root="$(cd "$(dirname "$0")/.." && pwd)"' \
            'exec "$sdk_root/dotnet" "$@"' \
            > "$out/bin/dotnet"
          chmod +x "$out/bin/dotnet"

          mkdir -p "$out/nix-support"
          cat > "$out/nix-support/setup-hook" <<'EOF'
          ${setupHook}
          EOF

          chmod -R a-w "$out"

          runHook postInstall
        '';

        passthru = rawSdk.passthru // {inherit rawSdk;} // buildDotnetModulePassthru finalSdk rawSdk.version;
        meta = rawSdk.meta;
      };
    in
      finalSdk
    else let
      finalSdk = pkgs.stdenv.mkDerivation {
        pname = rawSdk.pname;
        inherit (rawSdk) version;

        src = rawSdk;
        dontUnpack = true;

        installPhase = ''
          runHook preInstall

          mkdir -p "$out"
          cp -a "$src/." "$out/"
          chmod -R u+w "$out"

          mkdir -p "$out/nix-support"
          cat > "$out/nix-support/setup-hook" <<'EOF'
          ${setupHook}
          EOF

          chmod -R a-w "$out"

          runHook postInstall
        '';

        passthru = rawSdk.passthru // {inherit rawSdk;} // buildDotnetModulePassthru finalSdk rawSdk.version;
        meta = rawSdk.meta;
      };
    in
      finalSdk;

  mkDotnetSdk = {
    sdkVersion,
    workloads ? [],
    additionalSdkVersions ? [],
    installScriptUrl ? defaultInstallScriptUrl,
    installScriptSha256 ? defaultInstallScriptSha256,
    outputHash,
  }: let
    validatedSdkVersion = validateSdkVersion sdkVersion;
    validatedWorkloads = map validateWorkload workloads;
    validatedAdditionalSdkVersions = map validateSdkVersion additionalSdkVersions;
    validatedOutputHash = validateOutputHash outputHash;
    workloadNames = buildWorkloadNames validatedWorkloads;
    workloadPnameSuffix = buildWorkloadPnameSuffix validatedWorkloads;
    workloadCommands = buildWorkloadCommands validatedWorkloads;
    hasAdditionalSdks = validatedAdditionalSdkVersions != [];
    additionalSdkPnameSuffix =
      if hasAdditionalSdks
      then "-with-${pkgs.lib.concatStringsSep "-" validatedAdditionalSdkVersions}"
      else "";
    additionalInstallCommands =
      if hasAdditionalSdks
      then
        pkgs.lib.concatStringsSep "\n\n" (map
          (version: ''
            echo "Installing additional .NET SDK ${version} into $out"
            bash ./dotnet-install.sh \
              --version "${version}" \
              --install-dir "$out" \
              --no-path
          '')
          validatedAdditionalSdkVersions)
      else "";

    installScript = pkgs.fetchurl {
      url = installScriptUrl;
      sha256 = installScriptSha256;
    };

    rawSdk = pkgs.stdenv.mkDerivation {
      pname = sanitizePname "dotnet-sdk-${workloadPnameSuffix}${additionalSdkPnameSuffix}";
      version = validatedSdkVersion;

      src = null;
      dontUnpack = true;

      outputHashMode = "recursive";
      outputHashAlgo = "sha256";
      outputHash = validatedOutputHash;

      nativeBuildInputs = with pkgs;
        [
          curl
          cacert
          removeReferencesTo
        ]
        ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
          patchelf
          icu
          openssl
          zlib
        ];

      buildPhase = ''
        runHook preBuild

        mkdir -p "$out"

        echo "Using verified dotnet-install script from ${installScriptUrl}"
        cp ${installScript} dotnet-install.sh
        chmod +x dotnet-install.sh

        ${additionalInstallCommands}

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
        export DOTNET_CLI_TELEMETRY_OPTOUT=1
        export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
        export DOTNET_GENERATE_ASPNET_CERTIFICATE=0

        ${pkgs.lib.optionalString pkgs.stdenv.isLinux ''
          export LD_LIBRARY_PATH="${dotnetLibraryPath}"
        ''}

        mkdir -p "$DOTNET_CLI_HOME" "$NUGET_PACKAGES" "$NUGET_HTTP_CACHE_PATH"

        ${pkgs.lib.optionalString hasAdditionalSdks ''
          cat > global.json <<'EOF'
          {
            "sdk": {
              "version": "${validatedSdkVersion}",
              "rollForward": "disable"
            }
          }
          EOF
        ''}

        ${pkgs.lib.optionalString pkgs.stdenv.isLinux ''
          originalDotnetInterp=""
          if [ "${workloadNames}" != "none" ]; then
            originalDotnetInterp="$(patchelf --print-interpreter "$out/dotnet")"
            patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" "$out/dotnet"
          fi
        ''}

        ${workloadCommands}

        ${pkgs.lib.optionalString pkgs.stdenv.isLinux ''
          if [ "${workloadNames}" != "none" ]; then
            patchelf --set-interpreter "$originalDotnetInterp" "$out/dotnet"
          fi
        ''}

        if [ -d "$out/metadata/workloads" ]; then
          find "$out/metadata/workloads" -type d -name history -prune -exec rm -rf {} +
        fi

        rm -rf "$DOTNET_CLI_HOME" "$NUGET_PACKAGES" "$NUGET_HTTP_CACHE_PATH" "$HOME"
        ${pkgs.lib.optionalString hasAdditionalSdks ''
          rm -f global.json
        ''}

        mkdir -p "$out/bin" "$out/nix-support"

        ln -s ../dotnet "$out/bin/dotnet"

        cat > "$out/nix-support/setup-hook" <<'EOF'
        dotnetSdkRoot="$(cd "$(dirname "''${BASH_SOURCE[0]}")/.." && pwd)"
        export DOTNET_ROOT="$dotnetSdkRoot"
        EOF

        echo "Installation complete"
        echo "SDK Version: $($out/dotnet --version)"

        if [ -d "$out/metadata" ]; then
          echo "Removing store path references from workload metadata..."
          find "$out/metadata" -type f \( -name "*.json" -o -name "*.txt" \) 2>/dev/null | while read f; do
            sed -i "s|/nix/store/[^/]*/|$out/|g" "$f" 2>/dev/null || true
          done
        fi

        echo "Removing remaining self-references from output..."
        find "$out" -type f 2>/dev/null | while read f; do
          remove-references-to -t "$out" "$f" 2>/dev/null || true
        done

        runHook postBuild
      '';

      dontFixup = true;

      passthru =
        {
          inherit sdkVersion workloads installScriptUrl installScriptSha256;
          outputHash = validatedOutputHash;
          additionalSdkVersions = validatedAdditionalSdkVersions;
        }
        // buildDotnetModulePassthru rawSdk validatedSdkVersion;

      meta = with pkgs.lib; {
        description =
          if hasAdditionalSdks
          then ".NET SDK ${validatedSdkVersion} with workloads [${workloadNames}] and additional SDKs [${pkgs.lib.concatStringsSep ", " validatedAdditionalSdkVersions}]"
          else ".NET SDK ${validatedSdkVersion} with workloads [${workloadNames}]";
        homepage = "https://dotnet.microsoft.com/";
        license = licenses.mit;
        maintainers = [];
        mainProgram = "dotnet";
        platforms = supportedPlatforms;
      };
    };
  in
    finalizeRawSdk rawSdk;

  resolveDotnetConfig = {
    globalJsonPath ? null,
    sdkVersion ? null,
    workloadVersion ? null,
    workloads ? [],
  }: let
    usesGlobalJson = globalJsonPath != null;
    usesExplicitSdkVersion = sdkVersion != null;
    globalConfig =
      if usesGlobalJson
      then readGlobalJson globalJsonPath
      else {
        sdkVersion = null;
        workloadVersion = null;
      };
    resolvedSdkVersion =
      if usesGlobalJson
      then globalConfig.sdkVersion
      else sdkVersion;
    resolvedWorkloadVersion =
      if usesGlobalJson
      then globalConfig.workloadVersion
      else workloadVersion;
    workloadObjects =
      map
      (name: {
        inherit name;
        version = resolvedWorkloadVersion;
      })
      workloads;
    validatedWorkloads = map validateWorkload workloadObjects;
  in
    if usesGlobalJson && usesExplicitSdkVersion
    then throw "mkDotnet accepts either globalJsonPath or sdkVersion, not both."
    else if !(usesGlobalJson || usesExplicitSdkVersion)
    then throw "mkDotnet requires either globalJsonPath or sdkVersion."
    else if resolvedSdkVersion == null
    then throw "Could not read SDK version from ${toString globalJsonPath}. Make sure the file exists and has a 'sdk.version' field."
    else {
      sdkVersion = validateSdkVersion resolvedSdkVersion;
      workloads = validatedWorkloads;
    };

  mkDotnetSingle = config @ {
    outputHash ? null,
    outputHashes ? null,
    installScriptUrl ? defaultInstallScriptUrl,
    installScriptSha256 ? defaultInstallScriptSha256,
    ...
  }: let
    resolvedConfig = resolveDotnetConfig (removeAttrs config ["outputHash" "outputHashes" "installScriptUrl" "installScriptSha256"]);
    resolvedOutputHash =
      if outputHash != null
      then throw "mkDotnet no longer accepts outputHash. Use outputHashes keyed by Nix system."
      else resolveOutputHash outputHashes;
  in
    mkDotnetSdk {
      sdkVersion = resolvedConfig.sdkVersion;
      workloads = resolvedConfig.workloads;
      outputHash = resolvedOutputHash;
      inherit installScriptUrl installScriptSha256;
    };

  mkDotnetWithAdditional = {
    primaryConfig,
    additionalConfigs,
    outputHash ? null,
    outputHashes ? null,
    installScriptUrl ? defaultInstallScriptUrl,
    installScriptSha256 ? defaultInstallScriptSha256,
  }: let
    resolvedPrimary = resolveDotnetConfig primaryConfig;
    resolvedOutputHash =
      if outputHash != null
      then throw "mkDotnet no longer accepts outputHash. Use outputHashes keyed by Nix system."
      else resolveOutputHash outputHashes;
    resolvedAdditional = map resolveDotnetConfig additionalConfigs;
    additionalWithWorkloads = pkgs.lib.filter (config: config.workloads != []) resolvedAdditional;
    additionalVersions = map (config: config.sdkVersion) resolvedAdditional;
  in
    if additionalWithWorkloads != []
    then throw "additionalSdks entries with workloads are not supported yet."
    else
      mkDotnetSdk {
        sdkVersion = resolvedPrimary.sdkVersion;
        workloads = resolvedPrimary.workloads;
        additionalSdkVersions = additionalVersions;
        outputHash = resolvedOutputHash;
        inherit installScriptUrl installScriptSha256;
      };

  mkDotnet = args @ {additionalSdks ? [], ...}: let
    primaryArgs = removeAttrs args ["additionalSdks"];
    normalizedAdditionalConfigs =
      map
      (config:
        if builtins.hasAttr "additionalSdks" config && config.additionalSdks != []
        then throw "Nested additionalSdks are not supported. Add all SDK entries at the top-level additionalSdks list."
        else if builtins.hasAttr "outputHash" config || builtins.hasAttr "outputHashes" config
        then throw "additionalSdks entries should not set outputHash or outputHashes. Use top-level outputHashes for the combined installation."
        else removeAttrs config ["additionalSdks" "outputHash" "outputHashes"])
      additionalSdks;
  in
    if additionalSdks == []
    then mkDotnetSingle primaryArgs
    else
      mkDotnetWithAdditional {
        primaryConfig = removeAttrs primaryArgs ["outputHash" "outputHashes" "installScriptUrl" "installScriptSha256"];
        additionalConfigs = normalizedAdditionalConfigs;
        outputHash = primaryArgs.outputHash or null;
        outputHashes = primaryArgs.outputHashes or null;
        installScriptUrl = primaryArgs.installScriptUrl or defaultInstallScriptUrl;
        installScriptSha256 = primaryArgs.installScriptSha256 or defaultInstallScriptSha256;
      };
in {
  inherit mkDotnet;
  internal = lib;
}

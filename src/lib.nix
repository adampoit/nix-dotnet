{
  pkgs,
  hashCachePath ? ../sdk-hashes.json,
}: let
  inherit
    (pkgs.lib)
    concatStringsSep
    map
    match
    hasAttr
    replaceStrings
    foldl'
    splitString
    optionalString
    getAttr
    ;
  getPlatform = {}:
    if pkgs.stdenv.isLinux
    then "linux"
    else if pkgs.stdenv.isDarwin
    then "osx"
    else throw "Unsupported platform: only Linux and macOS are supported";
in {
  inherit getPlatform;

  validateSdkVersion = version: let
    validPattern = "^[0-9]+\\.[0-9]+(\\.[0-9]+)?(-.*)?$";
  in
    if match validPattern version != null
    then version
    else throw "Invalid SDK version format: ${version}. Expected format: X.Y.Z (e.g., 8.0.100)";

  validateWorkload = w:
    if !(hasAttr "name" w)
    then throw "Workload missing required 'name' attribute. Available attributes: ${toString (builtins.attrNames w)}"
    else w;

  buildWorkloadNames = workloads:
    if workloads == []
    then "none"
    else concatStringsSep "-" (map (w: w.name) workloads);

  buildWorkloadCommands = workloads:
    if workloads == []
    then "echo 'No workloads to install'"
    else
      concatStringsSep "\n\n" (map
        (w: let
          versionFlag =
            if hasAttr "version" w
            then "--version ${w.version}"
            else "";
        in ''
          echo "Installing workload ${w.name}${optionalString (hasAttr "version" w) " (version=${w.version})"}"
          "$out/dotnet" workload install ${w.name} ${versionFlag}
        '')
        workloads);

  sanitizePname = name: let
    unsafeChars = ["@" " " "/" "\\" "*" "?" "<" ">" "|"];
    replaceUnsafe = c: str: replaceStrings [c] ["_"] str;
  in
    foldl' (str: c: replaceUnsafe c str) name unsafeChars;

  parseSdkVersion = version: let
    parts = splitString "." version;
  in {
    major = builtins.elemAt parts 0;
    minor = builtins.elemAt parts 1;
    patch =
      if builtins.length parts > 2
      then builtins.elemAt parts 2
      else "0";
  };

  readGlobalJson = path: let
    jsonContent = builtins.readFile path;
    json = builtins.fromJSON jsonContent;
  in {
    sdkVersion =
      if hasAttr "sdk" json && hasAttr "version" json.sdk
      then json.sdk.version
      else null;
    workloadVersion =
      if hasAttr "sdk" json && hasAttr "workloadVersion" json.sdk
      then json.sdk.workloadVersion
      else null;
  };

  getSdkUrl = version: arch: let
    platform = getPlatform {};
  in "https://builds.dotnet.microsoft.com/dotnet/Sdk/${version}/dotnet-sdk-${version}-${platform}-${arch}.tar.gz";

  getSdkHash = version: arch: let
    hashCache =
      if builtins.pathExists hashCachePath
      then builtins.fromJSON (builtins.readFile hashCachePath)
      else {hashes = {};};
    platform = getPlatform {};
    cacheKey = "${platform}-${arch}";
    versionHashes =
      if hasAttr version hashCache.hashes
      then getAttr version hashCache.hashes
      else throw "No hash found for SDK version ${version}. Run 'nix run .#prefetch-sdk ${version}' to compute and cache the hash.";
  in
    if hasAttr cacheKey versionHashes
    then getAttr cacheKey versionHashes
    else throw "No hash found for SDK version ${version} on ${cacheKey}. Run 'nix run .#prefetch-sdk ${version}' to compute and cache the hash.";
}

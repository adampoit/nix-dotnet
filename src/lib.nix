{pkgs}: let
  inherit
    (pkgs.lib)
    concatStringsSep
    map
    match
    hasAttr
    replaceStrings
    foldl'
    splitString
    ;
in {
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

  buildWorkloadPnameSuffix = workloads:
    if workloads == []
    then "none"
    else
      concatStringsSep "-" (map
        (w:
          if hasAttr "version" w && w.version != null
          then "${w.name}-${w.version}"
          else w.name)
        workloads);

  buildWorkloadCommands = workloads:
    if workloads == []
    then "echo 'No workloads to install'"
    else
      concatStringsSep "\n\n" (map
        (w: let
          hasVersion = hasAttr "version" w && w.version != null;
          installFlags =
            if hasVersion
            then " --version ${w.version}"
            else " --skip-manifest-update";
        in ''
          echo "Installing workload ${w.name}"
          "$out/dotnet" workload install ${w.name}${installFlags}
        '')
        workloads);

  sanitizePname = name: let
    unsafeChars = ["@" " " "/" "\\" "*" "?" "<" ">" "|"];
    replaceUnsafe = c: str: replaceStrings [c] ["_"] str;
  in
    foldl' (str: c: replaceUnsafe c str) name unsafeChars;

  validateOutputHash = outputHash:
    if outputHash == null
    then throw "outputHash is required. Use the hash from a prior build mismatch to keep derivations reproducible."
    else if outputHash == ""
    then throw "outputHash cannot be empty."
    else outputHash;

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
}

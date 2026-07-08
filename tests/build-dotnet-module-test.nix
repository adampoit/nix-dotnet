{
  pkgs,
  dotnet,
  outputHashes,
}: let
  inherit (pkgs) lib;

  dotnetSdk = dotnet.mkDotnet {
    globalJsonPath = ./build-dotnet-module/global.json;
    workloads = [];
    inherit outputHashes;
  };
in
  pkgs.buildDotnetModule {
    pname = "nix-dotnet-build-dotnet-module-test";
    version = "1.0.0";

    src = ./build-dotnet-module/src;

    projectFile = "HelloApp/HelloApp.csproj";
    nugetDeps = ./build-dotnet-module/nuget-deps.json;

    dotnet-sdk = dotnetSdk;
    dotnet-runtime = pkgs.dotnetCorePackages.aspnetcore_10_0;

    executables = ["HelloApp"];

    meta = {
      description = "Repro for buildDotnetModule + nix-dotnet SDK (ref/runtime packs via dotnet-sdk.packages)";
      mainProgram = "HelloApp";
      platforms = lib.platforms.unix;
    };
  }

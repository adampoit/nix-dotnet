{
  pkgs,
  dotnet,
  outputHashes,
}: let
  inherit (pkgs) lib;

  dotnetSdk = dotnet.mkDotnet {
    globalJsonPath = ./global.json;
    workloads = [];
    inherit outputHashes;
  };
in
  pkgs.buildDotnetModule {
    pname = "nix-dotnet-build-dotnet-module-e2e";
    version = "1.0.0";

    src = ./src;

    projectFile = "HelloApp/HelloApp.csproj";
    nugetDeps = ./nuget-deps.json;

    dotnet-sdk = dotnetSdk;
    dotnet-runtime = pkgs.dotnetCorePackages.aspnetcore_10_0;

    executables = ["HelloApp"];

    meta = {
      description = "e2e test for buildDotnetModule with nix-dotnet SDK";
      mainProgram = "HelloApp";
      platforms = lib.platforms.unix;
    };
  }

{
  lib,
  dotnet,
}: let
  validGlobalJson = builtins.toFile "global-valid.json" ''
    {
      "sdk": {
        "version": "10.0.103",
        "rollForward": "disable",
        "workloadVersion": "10.0.100.1"
      }
    }
  '';

  globalJsonWithoutWorkloadVersion = builtins.toFile "global-no-workload-version.json" ''
    {
      "sdk": {
        "version": "10.0.103",
        "rollForward": "disable"
      }
    }
  '';

  globalJsonMissingSdkVersion = builtins.toFile "global-missing-sdk-version.json" ''
    {
      "sdk": {
        "rollForward": "disable"
      }
    }
  '';

  globalJsonInvalidSdkVersion = builtins.toFile "global-invalid-sdk-version.json" ''
    {
      "sdk": {
        "version": "not-a-version"
      }
    }
  '';

  validOutputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  validOutputHashes = {
    x86_64-linux = validOutputHash;
    aarch64-linux = validOutputHash;
    x86_64-darwin = validOutputHash;
    aarch64-darwin = validOutputHash;
  };

  mkDotnetFrom = globalJsonPath: workloads:
    dotnet.mkDotnet {
      inherit globalJsonPath workloads;
      outputHashes = validOutputHashes;
    };

  mkDotnetFromVersion = sdkVersion: workloadVersion: workloads:
    dotnet.mkDotnet {
      inherit sdkVersion workloadVersion workloads;
      outputHashes = validOutputHashes;
    };
in {
  testValidateSdkVersionBasic = {
    expr = lib.validateSdkVersion "10.0.100";
    expected = "10.0.100";
  };

  testValidateSdkVersionShort = {
    expr = lib.validateSdkVersion "10.0";
    expected = "10.0";
  };

  testValidateSdkVersionPreview = {
    expr = lib.validateSdkVersion "10.0.100-preview.1";
    expected = "10.0.100-preview.1";
  };

  testValidateSdkVersionOld = {
    expr = lib.validateSdkVersion "9.0.404";
    expected = "9.0.404";
  };

  testValidateWorkloadValid = {
    expr = lib.validateWorkload {
      name = "android";
      version = "10.0.100.1";
    };
    expected = {
      name = "android";
      version = "10.0.100.1";
    };
  };

  testValidateWorkloadMaui = {
    expr = lib.validateWorkload {
      name = "maui";
      version = "10.0.100.1";
      extra = "data";
    };
    expected = {
      name = "maui";
      version = "10.0.100.1";
      extra = "data";
    };
  };

  testBuildWorkloadNamesEmpty = {
    expr = lib.buildWorkloadNames [];
    expected = "none";
  };

  testBuildWorkloadNamesSingle = {
    expr = lib.buildWorkloadNames [
      {
        name = "android";
        version = "10.0.100.1";
      }
    ];
    expected = "android";
  };

  testBuildWorkloadNamesMultiple = {
    expr = lib.buildWorkloadNames [
      {
        name = "android";
        version = "10.0.100.1";
      }
      {
        name = "ios";
        version = "10.0.100.1";
      }
      {
        name = "maui";
        version = "10.0.100.1";
      }
    ];
    expected = "android-ios-maui";
  };

  testBuildWorkloadPnameSuffixEmpty = {
    expr = lib.buildWorkloadPnameSuffix [];
    expected = "none";
  };

  testBuildWorkloadPnameSuffixSingleWithVersion = {
    expr = lib.buildWorkloadPnameSuffix [
      {
        name = "android";
        version = "10.0.100.1";
      }
    ];
    expected = "android-10.0.100.1";
  };

  testBuildWorkloadPnameSuffixMultipleMixed = {
    expr = lib.buildWorkloadPnameSuffix [
      {
        name = "android";
        version = "10.0.100.1";
      }
      {
        name = "ios";
      }
    ];
    expected = "android-10.0.100.1-ios";
  };

  testBuildWorkloadCommandsEmpty = {
    expr = lib.buildWorkloadCommands [];
    expected = "echo 'No workloads to install'";
  };

  testBuildWorkloadCommandsWithVersion = {
    expr = lib.buildWorkloadCommands [
      {
        name = "android";
        version = "10.0.100.1";
      }
    ];
    expected = ''
      echo "Installing workload android"
      "$out/dotnet" workload install android --version 10.0.100.1
    '';
  };

  testBuildWorkloadCommandsWithoutVersion = {
    expr = lib.buildWorkloadCommands [
      {
        name = "android";
      }
    ];
    expected = ''
      echo "Installing workload android"
      "$out/dotnet" workload install android --skip-manifest-update
    '';
  };

  testSanitizePnameBasic = {
    expr = lib.sanitizePname "dotnet-sdk-10.0.100-none-packs";
    expected = "dotnet-sdk-10.0.100-none-packs";
  };

  testSanitizePnameWithSpaces = {
    expr = lib.sanitizePname "dotnet sdk 10.0.100";
    expected = "dotnet_sdk_10.0.100";
  };

  testSanitizePnameWithSpecialChars = {
    expr = lib.sanitizePname "dotnet@sdk/10.0";
    expected = "dotnet_sdk_10.0";
  };

  testParseSdkVersionBasic = {
    expr = lib.parseSdkVersion "10.0.100";
    expected = {
      major = "10";
      minor = "0";
      patch = "100";
    };
  };

  testParseSdkVersionShort = {
    expr = lib.parseSdkVersion "9.0";
    expected = {
      major = "9";
      minor = "0";
      patch = "0";
    };
  };

  testValidateSdkVersionInvalidFormat = {
    expr = builtins.tryEval (lib.validateSdkVersion "invalid-version");
    expected = {
      success = false;
      value = false;
    };
  };

  testValidateSdkVersionEmpty = {
    expr = builtins.tryEval (lib.validateSdkVersion "");
    expected = {
      success = false;
      value = false;
    };
  };

  testValidateWorkloadMissingName = {
    expr = builtins.tryEval (lib.validateWorkload {
      version = "10.0.100.1";
    });
    expected = {
      success = false;
      value = false;
    };
  };

  testValidateOutputHashValid = {
    expr = lib.validateOutputHash validOutputHash;
    expected = validOutputHash;
  };

  testValidateOutputHashNull = {
    expr = builtins.tryEval (lib.validateOutputHash null);
    expected = {
      success = false;
      value = false;
    };
  };

  testValidateOutputHashEmpty = {
    expr = builtins.tryEval (lib.validateOutputHash "");
    expected = {
      success = false;
      value = false;
    };
  };

  testReadGlobalJsonWithWorkloadVersion = {
    expr = lib.readGlobalJson validGlobalJson;
    expected = {
      sdkVersion = "10.0.103";
      workloadVersion = "10.0.100.1";
    };
  };

  testReadGlobalJsonWithoutWorkloadVersion = {
    expr = lib.readGlobalJson globalJsonWithoutWorkloadVersion;
    expected = {
      sdkVersion = "10.0.103";
      workloadVersion = null;
    };
  };

  testReadGlobalJsonMissingSdkVersion = {
    expr = lib.readGlobalJson globalJsonMissingSdkVersion;
    expected = {
      sdkVersion = null;
      workloadVersion = null;
    };
  };

  testMkDotnetVersionFromGlobalJson = {
    expr = (mkDotnetFrom validGlobalJson []).version;
    expected = "10.0.103";
  };

  testMkDotnetVersionFromExplicitSdkVersion = {
    expr = (mkDotnetFromVersion "9.0.404" null []).version;
    expected = "9.0.404";
  };

  testMkDotnetPnameWithVersionedWorkloads = {
    expr =
      (mkDotnetFrom validGlobalJson [
        "android"
        "ios"
      ]).pname;
    expected = "dotnet-sdk-android-10.0.100.1-ios-10.0.100.1";
  };

  testMkDotnetPnameWithoutWorkloadVersion = {
    expr = (mkDotnetFrom globalJsonWithoutWorkloadVersion ["android"]).pname;
    expected = "dotnet-sdk-android";
  };

  testMkDotnetMainProgram = {
    expr = (mkDotnetFrom validGlobalJson []).meta.mainProgram;
    expected = "dotnet";
  };

  testMkDotnetPassthruWorkloads = {
    expr =
      (mkDotnetFrom validGlobalJson [
        "android"
        "ios"
      ]).passthru.workloads;
    expected = [
      {
        name = "android";
        version = "10.0.100.1";
      }
      {
        name = "ios";
        version = "10.0.100.1";
      }
    ];
  };

  testMkDotnetPassthruWorkloadsFromExplicitWorkloadVersion = {
    expr =
      (mkDotnetFromVersion "9.0.404" "9.0.100" [
        "android"
      ]).passthru.workloads;
    expected = [
      {
        name = "android";
        version = "9.0.100";
      }
    ];
  };

  testMkDotnetAcceptsInstallScriptOverrides = {
    expr =
      (dotnet.mkDotnet {
        globalJsonPath = validGlobalJson;
        outputHashes = validOutputHashes;
        installScriptUrl = "https://example.com/dotnet-install.sh";
        installScriptSha256 = "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=";
      }).passthru.installScriptUrl;
    expected = "https://example.com/dotnet-install.sh";
  };

  testMkDotnetAdditionalSdksAcceptInstallScriptOverrides = {
    expr =
      (dotnet.mkDotnet {
        sdkVersion = "10.0.103";
        outputHashes = validOutputHashes;
        installScriptUrl = "https://example.com/dotnet-install.sh";
        installScriptSha256 = "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=";
        additionalSdks = [
          {
            sdkVersion = "9.0.404";
          }
        ];
      }).passthru.installScriptSha256;
    expected = "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=";
  };

  testMkDotnetAcceptsOutputHashes = {
    expr =
      (dotnet.mkDotnet {
        globalJsonPath = validGlobalJson;
        outputHashes = validOutputHashes;
      }).passthru.outputHash;
    expected = validOutputHash;
  };

  testMkDotnetAdditionalSdksAcceptOutputHashes = {
    expr =
      (dotnet.mkDotnet {
        sdkVersion = "10.0.103";
        outputHashes = validOutputHashes;
        additionalSdks = [
          {
            sdkVersion = "9.0.404";
          }
        ];
      }).passthru.outputHash;
    expected = validOutputHash;
  };

  testMkDotnetRejectsOutputHash = {
    expr = builtins.tryEval (builtins.seq
      (dotnet.mkDotnet {
        sdkVersion = "10.0.103";
        outputHash = validOutputHash;
      }).outPath
      true);
    expected = {
      success = false;
      value = false;
    };
  };

  testMkDotnetRejectsMissingSystemOutputHash = {
    expr = builtins.tryEval (builtins.seq
      (dotnet.mkDotnet {
        sdkVersion = "10.0.103";
        outputHashes = {};
      }).outPath
      true);
    expected = {
      success = false;
      value = false;
    };
  };

  testMkDotnetBuildDotnetModulePackages = {
    expr = let
      sdk = mkDotnetFrom validGlobalJson [];
    in
      # packages must be the nixpkgs ref/runtime packs (so buildDotnetModule can
      # restore offline), not just the SDK derivation itself.
      builtins.length sdk.packages
      > 1
      && builtins.any (
        p: p ? name && builtins.match "Microsoft.NETCore.App.Ref-.*" p.name != null
      )
      sdk.packages;
    expected = true;
  };

  testMkDotnetBuildDotnetModuleIcu = {
    expr = let
      sdk = mkDotnetFrom validGlobalJson [];
    in
      sdk ? icu && sdk.icu ? outPath;
    expected = true;
  };

  testMkDotnetBuildDotnetModuleTargetPackages = {
    expr = let
      sdk = mkDotnetFrom validGlobalJson [];
    in
      sdk ? targetPackages && builtins.hasAttr "osx-arm64" sdk.targetPackages;
    expected = true;
  };

  testMkDotnetPassthruBuildDotnetModulePackages = {
    expr = let
      sdk = mkDotnetFrom validGlobalJson [];
    in
      builtins.length sdk.passthru.packages
      > 1
      && builtins.any (
        p: p ? name && builtins.match "Microsoft.AspNetCore.App.Ref-.*" p.name != null
      )
      sdk.passthru.packages;
    expected = true;
  };

  testMkDotnetPassthruBuildDotnetModuleTargetPackages = {
    expr = let
      sdk = mkDotnetFrom validGlobalJson [];
    in
      sdk.passthru ? targetPackages && builtins.hasAttr "osx-arm64" sdk.passthru.targetPackages;
    expected = true;
  };

  testMkDotnetRequiresVersionSource = {
    expr = builtins.tryEval (dotnet.mkDotnet {
      workloads = [];
      outputHashes = validOutputHashes;
    });
    expected = {
      success = false;
      value = false;
    };
  };

  testMkDotnetRejectsMixedVersionSources = {
    expr = builtins.tryEval (dotnet.mkDotnet {
      globalJsonPath = validGlobalJson;
      sdkVersion = "9.0.404";
      workloads = [];
      outputHashes = validOutputHashes;
    });
    expected = {
      success = false;
      value = false;
    };
  };

  testMkDotnetMissingSdkVersion = {
    expr = builtins.tryEval (mkDotnetFrom globalJsonMissingSdkVersion []);
    expected = {
      success = false;
      value = false;
    };
  };

  testMkDotnetInvalidSdkVersion = {
    expr = builtins.tryEval (mkDotnetFrom globalJsonInvalidSdkVersion []);
    expected = {
      success = false;
      value = false;
    };
  };

  testMkDotnetAdditionalSdksVersions = {
    expr =
      (dotnet.mkDotnet {
        sdkVersion = "10.0.103";
        outputHashes = validOutputHashes;
        additionalSdks = [
          {
            sdkVersion = "9.0.404";
          }
        ];
      }).passthru.additionalSdkVersions;
    expected = ["9.0.404"];
  };

  testMkDotnetAdditionalSdksNestedRejected = {
    expr = builtins.tryEval (dotnet.mkDotnet {
      sdkVersion = "10.0.103";
      outputHashes = validOutputHashes;
      additionalSdks = [
        {
          sdkVersion = "9.0.404";
          additionalSdks = [
            {
              sdkVersion = "8.0.100";
            }
          ];
        }
      ];
    });
    expected = {
      success = false;
      value = false;
    };
  };

  testMkDotnetAdditionalSdksRejectOutputHash = {
    expr = builtins.tryEval (dotnet.mkDotnet {
      sdkVersion = "10.0.103";
      outputHashes = validOutputHashes;
      additionalSdks = [
        {
          sdkVersion = "9.0.404";
          outputHash = validOutputHash;
        }
      ];
    });
    expected = {
      success = false;
      value = false;
    };
  };

  testMkDotnetAdditionalSdksRejectOutputHashes = {
    expr = builtins.tryEval (dotnet.mkDotnet {
      sdkVersion = "10.0.103";
      outputHashes = validOutputHashes;
      additionalSdks = [
        {
          sdkVersion = "9.0.404";
          outputHashes = validOutputHashes;
        }
      ];
    });
    expected = {
      success = false;
      value = false;
    };
  };

  testMkDotnetAdditionalSdksRejectWorkloads = {
    expr = builtins.tryEval (dotnet.mkDotnet {
      sdkVersion = "10.0.103";
      outputHashes = validOutputHashes;
      additionalSdks = [
        {
          sdkVersion = "9.0.404";
          workloads = ["android"];
        }
      ];
    });
    expected = {
      success = false;
      value = false;
    };
  };
}

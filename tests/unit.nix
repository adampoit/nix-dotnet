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

  mkDotnetFrom = globalJsonPath: workloads: outputHash:
    dotnet.mkDotnet {
      inherit globalJsonPath workloads;
      inherit outputHash;
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
    expr = (mkDotnetFrom validGlobalJson [] validOutputHash).version;
    expected = "10.0.103";
  };

  testMkDotnetPnameWithVersionedWorkloads = {
    expr =
      (mkDotnetFrom validGlobalJson [
          "android"
          "ios"
        ]
        validOutputHash).pname;
    expected = "dotnet-sdk-android-10.0.100.1-ios-10.0.100.1";
  };

  testMkDotnetPnameWithoutWorkloadVersion = {
    expr = (mkDotnetFrom globalJsonWithoutWorkloadVersion ["android"] validOutputHash).pname;
    expected = "dotnet-sdk-android";
  };

  testMkDotnetPassthruWorkloads = {
    expr =
      (mkDotnetFrom validGlobalJson [
          "android"
          "ios"
        ]
        validOutputHash).passthru.workloads;
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

  testMkDotnetMissingSdkVersion = {
    expr = builtins.tryEval (mkDotnetFrom globalJsonMissingSdkVersion [] validOutputHash);
    expected = {
      success = false;
      value = false;
    };
  };

  testMkDotnetInvalidSdkVersion = {
    expr = builtins.tryEval (mkDotnetFrom globalJsonInvalidSdkVersion [] validOutputHash);
    expected = {
      success = false;
      value = false;
    };
  };
}

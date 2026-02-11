{lib}: {
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
}

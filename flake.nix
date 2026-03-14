{
  description = "Nix module for reproducible .NET SDKs from global.json or explicit versions";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nix-unit.url = "github:nix-community/nix-unit";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    nix-unit,
    ...
  }:
    flake-utils.lib.eachDefaultSystem
    (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
        dotnet = import ./src/nix-dotnet.nix {inherit pkgs;};
        sdkOutputHashes = {
          aarch64-darwin = "sha256-YxvVtFxTcXR982ar15JUpKhv05WQ4AE4+xH1wxk3yz4=";
          aarch64-linux = "sha256-t4lHygbZMs2Mdry+rqSgSxhXWubWrC3uj1iIogyBE/U=";
          x86_64-darwin = "sha256-LX1c87zNmSv/ylVsOWoe9cySVotLeoQ2m05mW6ooT8E=";
          x86_64-linux = "sha256-kp0avinB5M1ZpWbdBBArpdsMVdRXqDX3FPF2lSBnWt0=";
        };
        workloadOutputHashes = {
          aarch64-darwin = "sha256-PPi+v18l/RAY9AtC92wPJapHfXHHUNYFcjHjmB3GkZM=";
          aarch64-linux = "sha256-IOo5a1RSjnouRl79Xru01XYdqtiNXS+pgrCa1Fx4+sI=";
          x86_64-darwin = "sha256-7KqU4jd0twDkplMjtaBSVFv/iYwYG1rDoflyKyZwaFE=";
          x86_64-linux = "sha256-fvgGMjgceFxb4SpkAZVbxlFD3xBGoc8eehSXdn9OLgA=";
        };
        multiSdkOutputHashes = {
          aarch64-darwin = "sha256-+hbEyapmxU8+JLahaIhv47vyNgyvP51QZJsSIEWx9lg=";
          aarch64-linux = "sha256-olZbB/1rbLs587K9NQXBQ9o2pQH0WSTUjaBORlJVD+4=";
          x86_64-darwin = "sha256-mHNWI7TtbIKXZSlcrxQFSjmU9f+3Em4u2lqIKSmBiso=";
          x86_64-linux = "sha256-qIqid6wnv4OBC5BuvvZL1FvFXKge7k1PzrdqXpIk5fc=";
        };
        outputHashFor = hashes:
          if builtins.hasAttr system hashes
          then hashes.${system}
          else throw "No outputHash configured for system ${system}";
        integrationSingleSdkTest = import ./tests/integration-test.nix {
          inherit pkgs dotnet;
          outputHash = outputHashFor sdkOutputHashes;
        };
        integrationWorkloadTest = import ./tests/integration-workload-test.nix {
          inherit pkgs dotnet;
          outputHash = outputHashFor workloadOutputHashes;
        };
        integrationMultiSdkTest = import ./tests/integration-multi-sdk-test.nix {
          inherit pkgs dotnet;
          outputHash = outputHashFor multiSdkOutputHashes;
        };
        integrationTests =
          pkgs.runCommand
          "integration-tests"
          {
            buildInputs = [
              integrationSingleSdkTest
              integrationWorkloadTest
              integrationMultiSdkTest
            ];
          }
          ''
            touch $out
          '';
        unitTests = import ./tests/unit.nix {
          lib = dotnet.internal;
          inherit dotnet;
        };

        unitTestAssertions =
          map
          (
            name: let
              test = unitTests.${name};
            in
              if test.expr == test.expected
              then true
              else throw "Unit test failed: ${name}"
          )
          (builtins.attrNames unitTests);
      in {
        lib = dotnet;
        packages = let
          basicExample = dotnet.mkDotnet {
            globalJsonPath = ./global.json;
            workloads = [];
            outputHash = outputHashFor sdkOutputHashes;
          };

          workloadExample = dotnet.mkDotnet {
            globalJsonPath = ./global.json;
            workloads = ["android"];
            outputHash = outputHashFor workloadOutputHashes;
          };
        in {
          default = basicExample;
          basic-example = basicExample;
          workload-example = workloadExample;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            alejandra
            nil
            nix-unit.packages.${system}.default
          ];
        };

        checks = {
          fmt =
            pkgs.runCommand "check-fmt"
            {
              buildInputs = [pkgs.alejandra];
            } "
                alejandra --check ${./.}
                touch $out
              ";

          unit-tests = builtins.deepSeq unitTestAssertions (pkgs.runCommand "unit-tests" {} ''
            echo "${toString (builtins.length (builtins.attrNames unitTests))} unit tests passed" > $out
          '');

          integration-tests = integrationTests;
        };
      }
    )
    // {
      templates = {
        default = {
          path = ./examples/basic;
          description = "Basic nix-dotnet example";
        };
        with-workloads = {
          path = ./examples/with-workloads;
          description = "Example with .NET workloads";
        };
        multi-sdk = {
          path = ./examples/multi-sdk;
          description = "Example with one dotnet exposing multiple SDK versions";
        };
      };

      tests = let
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        dotnet = import ./src/nix-dotnet.nix {inherit pkgs;};
      in
        import ./tests/unit.nix {
          lib = dotnet.internal;
          inherit dotnet;
        };
    };
}

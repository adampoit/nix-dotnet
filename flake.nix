{
  description = "Nix module for installing .NET SDKs with specific versions and workloads from global.json";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nix-unit.url = "github:nix-community/nix-unit";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    nix-unit,
  }:
    flake-utils.lib.eachDefaultSystem
    (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
        dotnet = import ./src/nix-dotnet.nix {inherit pkgs;};
        sdkOutputHashes = {
          aarch64-darwin = "sha256-QrDQHIjGxhQu0dqbXFw5idaQ74G6qml0xoNPX+rbEPs=";
          aarch64-linux = "sha256-t4lHygbZMs2Mdry+rqSgSxhXWubWrC3uj1iIogyBE/U=";
          x86_64-darwin = "sha256-bWnl7oDH6ywF2iwFlQ+b1NZ6f5JvRtauaqIQIlz4Mzg=";
          x86_64-linux = "sha256-zavpTqfPO/x1YFvGww+QBzyK70eGi50TaA5wkaGziFg=";
        };
        workloadOutputHashes = {
          aarch64-darwin = "sha256-PXo7/caO02xsbx2qWcUIXtyvvr2ePifPdvMVzO9+JUE=";
          aarch64-linux = "sha256-IOo5a1RSjnouRl79Xru01XYdqtiNXS+pgrCa1Fx4+sI=";
          x86_64-darwin = "sha256-gJPf567EoBmF22ANZX9qFEA/wtZHU/+GBd6rbaj9VUQ=";
          x86_64-linux = "sha256-R6+gCgcfrTv1NYQyI0/3YXmjDRvvooPEOjCR59WSpfk=";
        };
        outputHashFor = hashes:
          if builtins.hasAttr system hashes
          then hashes.${system}
          else throw "No outputHash configured for system ${system}";
        unitTests = import ./tests/unit.nix {
          lib = dotnet.internal;
          inherit dotnet;
        };

        unitTestAssertions =
          builtins.map
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
        packages = {
          basic-example = dotnet.mkDotnet {
            globalJsonPath = ./global.json;
            workloads = [];
            outputHash = outputHashFor sdkOutputHashes;
          };

          workload-example = dotnet.mkDotnet {
            globalJsonPath = ./global.json;
            workloads = ["android"];
            outputHash = outputHashFor workloadOutputHashes;
          };
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

          integration-test = import ./tests/integration-test.nix {
            inherit pkgs dotnet;
            outputHash = outputHashFor sdkOutputHashes;
          };

          integration-workload-test = import ./tests/integration-workload-test.nix {
            inherit pkgs dotnet;
            outputHash = outputHashFor workloadOutputHashes;
          };
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

{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-dotnet.url = "github:adampoit/nix-dotnet";
  };

  outputs = {
    nixpkgs,
    nix-dotnet,
  }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    devShells.${system}.default = pkgs.mkShell {
      packages = [
        (nix-dotnet.lib.${system}.mkDotnet {
          sdkVersion = "10.0.103";
          outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
          additionalSdks = [
            {
              sdkVersion = "9.0.304";
            }
          ];
        })
      ];

      shellHook = ''
        echo "Active SDK: $(dotnet --version)"
        echo "Installed SDKs:"
        dotnet --list-sdks
      '';
    };
  };
}

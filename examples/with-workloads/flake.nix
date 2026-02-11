{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-dotnet.url = "github:adampoit/nix-dotnet";
  };

  outputs = {
    self,
    nixpkgs,
    nix-dotnet,
  }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    devShells.${system}.default = pkgs.mkShell {
      buildInputs = [
        (nix-dotnet.lib.${system}.mkDotnet {
          globalJsonPath = ./global.json;
          workloads = ["android" "maui"];
        })
      ];

      shellHook = ''
        echo ".NET SDK $(dotnet --version) with workloads is ready!"
        echo "Installed workloads:"
        dotnet workload list
      '';
    };
  };
}

# nix-dotnet

A Nix module that reads your `global.json` and builds a reproducible .NET SDK derivation.

## Quick Start

**1. Create global.json:**

```json
{
  "sdk": {
    "version": "10.0.100",
    "rollForward": "disable",
    "workloadVersion": "10.0.100.1"
  }
}
```

**2. Use in your flake:**

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-dotnet.url = "github:adampoit/nix-dotnet";
  };

  outputs = { self, nixpkgs, nix-dotnet }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [
          (nix-dotnet.lib.${system}.mkDotnet {
            globalJsonPath = ./global.json;
            workloads = [ "android" "maui" ];
            outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
          })
        ];
      };
    };
}
```

## API Reference

### `mkDotnet`

```nix
nix-dotnet.lib.${system}.mkDotnet {
  globalJsonPath = ./global.json;  # Required
  workloads = [ "android" "ios" ];  # Optional
  outputHash = "sha256-...";       # Required for fixed-output
}
```

**Parameters:**

- `globalJsonPath` - Path to global.json (required)
- `workloads` - List of workload names (optional, versions from global.json)
- `outputHash` - Fixed-output derivation hash (required)

### Getting the outputHash

1. Use a placeholder hash
2. Build: `nix build` (fails with "hash mismatch")
3. Copy the "got:" hash from the error
4. Update your flake with the correct hash

**Note:** Workload installation requires executing `dotnet` during build, so you cannot cross-compile workload-enabled SDKs (e.g., building Linux workloads on macOS).

## Examples

- [`examples/basic/`](./examples/basic/) - SDK without workloads
- [`examples/with-workloads/`](./examples/with-workloads/) - SDK with MAUI workloads

## Supported Platforms

- `x86_64-linux`
- `aarch64-linux`
- `x86_64-darwin`
- `aarch64-darwin`

## Development

```bash
# Unit tests (fast)
nix run github:nix-community/nix-unit -- --flake '.#tests'

# Integration tests (slow, builds SDK)
nix build .#checks.<system>.integration-test --no-link

# All checks
nix flake check

# Build examples
nix build .#basic-example --no-link
nix build .#workload-example --no-link
```

## License

MIT

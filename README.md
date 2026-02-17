# nix-dotnet

A Nix module that reads your `global.json` file and builds a .NET SDK derivation with exactly the versions you specify. **Your global.json is the single source of truth.**

## Features

- **Single source of truth**: Everything comes from your `global.json` file
- **Workload support**: Install .NET workloads (MAUI, Android, iOS, etc.)
- **Reproducible builds**: Pure Nix derivations ensure consistent environments
- **Simple API**: Just specify workload names, versions come from global.json

## Quick Start

### 1. Create your global.json

```json
{
  "sdk": {
    "version": "10.0.100",
    "rollForward": "disable",
    "workloadVersion": "10.0.100.1"
  }
}
```

### 2. Use in your flake

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

The SDK/workload versions come from your `global.json`, and `outputHash` pins the final SDK output for reproducibility.

## API Reference

### `mkDotnet` Function

Creates a .NET SDK derivation using versions from your `global.json`:

```nix
nix-dotnet.lib.${system}.mkDotnet {
  # Required: Path to your global.json file
  globalJsonPath = ./global.json;

  # Optional: List of workload names to install
  # Versions are read from global.json's workloadVersion field
  workloads = [ "android" "ios" "maui" ];

  # Required: Fixed-output derivation hash for reproducibility
  # Use a placeholder first, then replace with the hash from the build error
  outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
}
```

### Fixed-Output Derivations (Reproducible Builds)

`mkDotnet` uses Nix fixed-output derivations. You must provide `outputHash`, which pins the exact hash of the installed SDK and ensures that:

- The build is 100% reproducible across machines and time
- No network access is required after the first successful build
- The output can be cached and distributed via binary caches

#### Using Fixed-Output Mode

1. Set `outputHash` to a placeholder:

```nix
nix-dotnet.lib.${system}.mkDotnet {
  globalJsonPath = ./global.json;
  workloads = [];
  outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
}
```

2. Build (it will fail and report the correct hash):

```bash
nix build .#my-sdk
# Error: hash mismatch...
# got: sha256-abc123...
```

3. Update with the correct hash:

```nix
outputHash = "sha256-abc123...";
```

4. Rebuild - now uses the binary cache!

#### Important Notes

- **Workloads**: Both SDK-only and workload installations support fixed-output derivations. The workload metadata (which contained store path references) is automatically removed during the build process.
- **Cross-compilation limitation**: Workload installation requires executing the `dotnet` binary during the build. This means you cannot build workload-enabled SDKs for a different platform (e.g., building Linux workloads on macOS). Workload builds must be done natively on the target platform.
- **Hash changes**: If Microsoft updates the SDK or workload packs, the hash will change. This is expected and ensures reproducibility.

**Required global.json format:**

```json
{
  "sdk": {
    "version": "10.0.100", // Required: SDK version
    "rollForward": "disable", // Optional: Roll forward policy
    "workloadVersion": "10.0.100.1" // Optional: Default workload version
  }
}
```

If `workloadVersion` is not specified in `global.json`, workloads will use their latest compatible version.

## Examples

See the [`examples/`](./examples/) directory:

- [`examples/basic/`](./examples/basic/) - Simple SDK installation
- [`examples/with-workloads/`](./examples/with-workloads/) - SDK with MAUI workloads

## How It Works

1. Reads SDK version from your `global.json` (`sdk.version`)
2. Reads default workload version from your `global.json` (`sdk.workloadVersion`)
3. Downloads and installs the exact SDK version
4. Installs specified workloads at the exact version from global.json
5. Returns a Nix derivation for use in dev shells

## Requirements

- Nix with flakes enabled
- `global.json` file with `sdk.version` field
- Internet connection during build (downloads SDK from Microsoft)

## Supported Platforms

- `x86_64-linux`
- `aarch64-linux`
- `x86_64-darwin`
- `aarch64-darwin`

## Development

### Running Tests

```bash
# Run unit tests (fast - pure Nix evaluation)
nix run github:nix-community/nix-unit -- --flake '.#tests'

# Run integration test (slow - builds .NET SDK and runs xUnit tests)
nix build .#checks.<system>.integration-test --no-link

# Run all checks including formatting and tests
nix flake check

# Build examples
nix build .#basic-example --no-link
nix build .#workload-example --no-link
```

### Test Structure

- **Unit tests** (`tests/unit.nix`): Fast pure Nix tests for validation/parsing logic (17 tests)
- **Integration tests** (`tests/integration/`): Full .NET project build and xUnit test execution (7 tests)
  - Located in `tests/integration/` directory
  - Builds a real .NET SDK using this module
  - Runs xUnit tests to verify the SDK works correctly

## Why global.json as the Only Source?

- **Consistency**: Matches how `dotnet` CLI works
- **Simplicity**: One file controls all versions
- **Team-friendly**: Easy to share and version control
- **CI/CD compatible**: Works naturally with existing .NET workflows

## License

MIT License - see [LICENSE](./LICENSE) for details.

## Acknowledgments

- Uses Microsoft's official [dotnet-install scripts](https://github.com/dotnet/install-scripts)
- Inspired by the need for version-pinned .NET SDKs in Nix environments

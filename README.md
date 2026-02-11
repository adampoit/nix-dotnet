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
          })
        ];
      };
    };
}
```

That's it! The SDK version and all workload versions come from your `global.json`.

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
}
```

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

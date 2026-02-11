# Basic Example

This example shows the simplest usage of nix-dotnet - installing a specific .NET SDK version without any workloads.

## Usage

```bash
nix develop
```

This will enter a shell with .NET SDK 8.0.100 available.

## Files

- `flake.nix` - The Nix flake defining the development shell
- `global.json` - Optional: pins the SDK version for the project

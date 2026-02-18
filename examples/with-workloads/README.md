# Workloads Example

SDK with MAUI, Android, and iOS workloads.

## Prerequisites

- Android SDK (for Android workload)
- Xcode (for iOS/macOS workloads)

## Usage

```bash
nix develop
```

The first build will fail with a hash mismatch. Copy the "got:" hash and update the `outputHash` in `flake.nix`.

## Available Workloads

- `android` - Android SDK
- `ios` - iOS
- `maccatalyst` - Mac Catalyst
- `macos` - macOS
- `maui` - .NET MAUI
- `wasm-tools` - WebAssembly tools
- `aspire` - .NET Aspire

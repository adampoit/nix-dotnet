# nix-dotnet - AGENTS.md

## Tech Stack

- Nix Flakes with nixpkgs unstable
- Pure Nix expressions (no external languages)
- nix-unit for testing
- alejandra for formatting

## Commands

- Format: `nix develop --command alejandra .`
- Check format: `nix develop --command alejandra --check .`
- Run all checks: `nix flake check`
- Unit tests: `nix run github:nix-community/nix-unit -- --flake '.#tests'`
- Run single unit test: `nix run github:nix-community/nix-unit -- --flake '.#tests' --filter 'testValidateSdkVersionBasic'`
- Integration test: `nix build .#checks.<system>.integration-test --no-link`
- Reproduce Linux integration checks in container: `./scripts/run-linux-build.sh`
- Run a specific Linux check in container: `./scripts/run-linux-build.sh .#checks.x86_64-linux.integration-test`
- Build basic example: `nix build .#basic-example --no-link`
- Build workload example: `nix build .#workload-example --no-link`
- Enter dev shell: `nix develop`

## Project Structure

- `src/nix-dotnet.nix` - Main module exporting `mkDotnet` function
- `src/lib.nix` - Pure functions for validation/parsing (unit tested)
- `tests/unit.nix` - Unit tests for lib.nix functions (17 tests)
- `tests/integration/` - Integration test .NET project (7 xUnit tests)
- `tests/integration-test.nix` - Integration test runner definition
- `examples/basic/` - Simple SDK usage example
- `examples/with-workloads/` - SDK with workloads example
- `flake.nix` - Main flake with packages, checks, and templates

## Code Style

- Use `inherit (pkgs.lib) func1 func2` for importing library functions
- Write modular, composable functions
- **Minimal comments**: Only use comments to explain non-obvious behavior, not to describe what the code does
- Use `throw` with descriptive messages for validation errors
- Prefer `let ... in` for complex expressions
- Use descriptive variable names (e.g., `validatedSdkVersion` not `v`)

```nix
# Good: clear function with validation and error handling
validateSdkVersion = version: let
  validPattern = "^[0-9]+\\.[0-9]+(\\.[0-9]+)?(-.*)?$";
in
  if match validPattern version != null
  then version
  else throw "Invalid SDK version format: ${version}";

# Good: modular function that builds on other functions
buildWorkloadNames = workloads:
  if workloads == []
  then "none"
  else concatStringsSep "-" (map (w: w.name) workloads);
```

## Testing

- **Unit tests** (fast, pure Nix):
  - Run: `nix run github:nix-community/nix-unit -- --flake '.#tests'`
  - Location: `tests/unit.nix`
  - Tests: Pure functions in `lib.nix` (validation, parsing)
  - Format:

  ```nix
  testMyFunction = {
    expr = lib.myFunction "input";
    expected = "expected-output";
  };
  ```

- **Integration tests** (slow, requires .NET SDK build):
  - Run: `nix build .#checks.<system>.integration-test --no-link`
  - Linux CI parity (from macOS): `./scripts/run-linux-build.sh`
  - The script uses a `nixos/nix` linux/amd64 container and defaults to both Linux integration checks.
  - Optional attrs can be passed (for example: `./scripts/run-linux-build.sh .#checks.x86_64-linux.integration-workload-test`).
  - Location: `tests/integration/` (full .NET project with xUnit tests)
  - Tests: End-to-end SDK build and test execution
  - Validates that mkDotnet produces a working .NET SDK

## Boundaries

**Always do:**

- Run tests after changes
- Keep functions in `lib.nix` pure (no side effects)
- Update tests when changing function behavior

**Ask first:**

- Adding new workload types
- Modifying CI/CD workflow
- Updating install script URLs/hashes

**Never do:**

- Skip tests when changing lib.nix
- Use impure functions (builtins.fetch\*) in lib.nix
- Break existing API without updating examples
- Hardcode platform-specific paths

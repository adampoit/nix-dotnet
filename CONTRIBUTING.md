# Contributing to nix-dotnet

Thank you for your interest in contributing to nix-dotnet!

## How to Contribute

1. **Fork the repository** and create your branch from `main`.
2. **Make your changes** and ensure they follow the existing code style.
3. **Test your changes** by running `nix flake check`.
4. **Update documentation** if needed (README, examples, etc.).
5. **Submit a pull request** with a clear description of your changes.

## Development Setup

```bash
# Clone your fork
git clone https://github.com/adampoit/nix-dotnet.git
cd nix-dotnet

# Enter development shell
nix develop
```

## Code Style

- Format all Nix files with `alejandra`
- Follow existing patterns in the codebase
- Keep functions modular and composable

## Testing

We use [nix-unit](https://github.com/nix-community/nix-unit) for unit testing. Before submitting a PR, ensure:

```bash
# Run unit tests
nix run github:nix-community/nix-unit -- --flake '.#tests'

# Check formatting
nix build .#checks.x86_64-linux.fmt --no-link

# Examples build successfully
nix build .#basic-example --no-link
nix build .#workload-example --no-link
```

### Writing Tests

Add unit tests to `tests/unit.nix`:

```nix
testMyFeature = {
  expr = lib.myFunction "input";
  expected = "expected-output";
};
```

## Reporting Issues

When reporting issues, please include:

- Your Nix version (`nix --version`)
- Your operating system and version
- Steps to reproduce the problem
- Expected vs actual behavior

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

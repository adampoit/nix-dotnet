# Contributing to nix-dotnet

## Development Setup

```bash
git clone https://github.com/adampoit/nix-dotnet.git
cd nix-dotnet
nix develop
```

## Making Changes

1. Fork and create a branch from `main`
2. Make changes following existing code style
3. Run `nix flake check` to test
4. Update documentation if needed
5. Submit a pull request

## Code Style

- Format with `alejandra`
- Keep functions modular and composable
- Add unit tests in `tests/unit.nix` for lib.nix changes

## Testing

```bash
# Unit tests
nix run github:nix-community/nix-unit -- --flake '.#tests'

# Integration tests
nix build .#checks.<system>.integration-test --no-link

# All checks
nix flake check
```

## Reporting Issues

Include:

- Nix version (`nix --version`)
- Operating system
- Steps to reproduce
- Expected vs actual behavior

## License

By contributing, you agree that your contributions will be licensed under MIT.

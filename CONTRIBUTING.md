# Contributing

Thanks for your interest in yaml2cv.

## Setup

Install [Nix](https://nixos.org/download) (flakes enabled) and, optionally,
[direnv](https://direnv.net). Then, in the repository root:

```sh
direnv allow     # or: nix develop
gleam test
```

## Workflow

- **Test first.** Add a failing test, make it pass, refactor.
- **Conventional Commits.** `feat: …`, `fix: …`, `docs: …`, `test: …`,
  `refactor: …`, `build: …`, `ci: …`, `chore: …`.
- **Green before commit.** `gleam format --check src test && gleam test`.
- **Design decisions** are documented as ADRs in [`docs/adr/`](docs/adr/).
  Propose a new ADR for any structural change.

More detail in [AGENTS.md](AGENTS.md).

## License

By contributing you agree that your contributions are licensed under the
[Apache License, Version 2.0](LICENSE).

# Contributing

Thanks for your interest in yaml2cv.

## Setup

All tools (Erlang/OTP, Gleam, rebar3, Typst, just, watchexec) come from the
Nix flake; nothing else needs to be installed globally.

1. Install [Nix](https://nixos.org/download) and enable flakes, e.g. in
   `~/.config/nix/nix.conf` or `/etc/nix/nix.conf`:

   ```
   experimental-features = nix-command flakes
   ```

2. Install [direnv](https://direnv.net) and
   [nix-direnv](https://github.com/nix-community/nix-direnv), then hook
   direnv into your shell (zsh shown):

   ```sh
   brew install direnv                      # or any other package manager
   nix profile add nixpkgs#nix-direnv
   mkdir -p ~/.config/direnv
   echo 'source $HOME/.nix-profile/share/nix-direnv/direnvrc' \
     >> ~/.config/direnv/direnvrc
   echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc
   ```

   nix-direnv caches the dev shell, so entering the directory is instant,
   and protects it from `nix store gc`.

3. In the repository root:

   ```sh
   direnv allow     # loads the dev shell whenever you enter the directory
   just check       # format check, type-check, tests
   ```

Without direnv, run `nix develop` to enter the shell manually.

### VSCode

Install the recommended extensions (VSCode suggests them when the folder is
opened; see `.vscode/extensions.json`). The **direnv** extension
(`mkhl.direnv`) is essential: it loads the dev shell into VSCode, so the
Gleam language server, Erlang tooling and the integrated terminal find the
pinned tools. When the environment changes (after `direnv allow` or a
`flake.lock` update), accept its prompt to restart the extension host.

## Workflow

- **Test first.** Add a failing test, make it pass, refactor.
- **Conventional Commits.** `feat: …`, `fix: …`, `docs: …`, `test: …`,
  `refactor: …`, `build: …`, `ci: …`, `chore: …`.
- **Green before commit.** `just check`.
- **Design decisions** are documented as ADRs in [`docs/adr/`](docs/adr/).
  Propose a new ADR for any structural change.

More detail in [AGENTS.md](AGENTS.md).

## License

By contributing you agree that your contributions are licensed under the
[Apache License, Version 2.0](LICENSE).

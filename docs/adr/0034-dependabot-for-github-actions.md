# 0034. Dependabot for GitHub Actions

- Status: Accepted
- Date: 2026-11-08

## Context

Only the latest release gets fixes (ADR 0033), so dependencies have to stay
current. All of them are pinned: GitHub Actions by commit SHA, Hex packages
in `manifest.toml` (ADR 0027), and Gleam, Erlang/OTP and Typst in
`flake.lock` and in the `Containerfile` with checksums (ADR 0013). Nothing
says when an update is available.

Dependabot supports GitHub Actions and Dockerfiles, but not Gleam/Hex
packages or Nix flakes. In the `Containerfile` the base image is an `ARG`
default, and the toolchain versions must change together with
`flake.nix`/`flake.lock`. An update to only one of them breaks ADR 0013.

## Options

1. **Manual only** — no noise, but security fixes in actions go unnoticed.
2. **Dependabot for GitHub Actions** — covers the one ecosystem it can
   update completely and correctly.
3. **Dependabot for Actions and Docker** — would also propose base image
   updates, but cannot keep them in step with the flake and checksums.
4. **Renovate** — more ecosystems through custom regex managers, but needs
   a third-party app and much more configuration.

## Decision

Option 2. `.github/dependabot.yml` checks GitHub Actions weekly and
groups all updates into one pull request. It keeps the SHA pin and the
version comment. Commits use the `ci` prefix to follow Conventional
Commits.

Gleam packages, the Nix flake, Erlang/OTP and Typst stay manual, using
the steps in AGENTS.md and ADR 0013.

## Consequences

- At most one Dependabot pull request per week; CI checks it as usual.
- The other dependencies still need a periodic manual check, e.g. before a
  release: `gleam deps update`, `nix flake update`, and new Erlang, Gleam
  and Typst releases.
- Dependabot security alerts are separate from version updates and can be
  enabled in the repository settings.

# 0005. Nix flake development environment

- Status: Accepted
- Date: 2026-11-07

## Context

Development needs Erlang/OTP, Gleam, rebar3 and Typst at known versions,
locally and in CI, without polluting the host.

## Options

1. **mise / asdf** — simple version pinning, relies on host build tools.
2. **Nix flake (+ direnv)** — fully reproducible shell, same in CI.
3. **Dev container only** — reproducible, slower edit/run loop.

## Decision

A Nix flake with a `devShells.default` providing all tools, pinned by
`flake.lock`, entered via `nix develop` or automatically with direnv
(`.envrc`: `use flake`). CI uses the same shell. Production images are built
from a separate `Containerfile` (podman/docker compatible).

## Consequences

- Contributors need Nix with flakes enabled.
- Tool upgrades happen via `nix flake update` and show up in review.

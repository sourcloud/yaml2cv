# 0027. Fail CI when manifest.toml drifts from gleam.toml

- Status: Accepted
- Date: 2026-11-08

## Context

The Nix flake (ADR 0005) pins the toolchain, but Hex dependencies are
fetched by `gleam` itself. Reproducibility of the dependency set rests on
the committed `manifest.toml`, which locks exact versions and SHA-256
checksums. The version ranges in `gleam.toml` only constrain the resolver.

Gleam re-resolves silently whenever `manifest.toml` no longer satisfies
`gleam.toml` (for example after editing a range without committing the
regenerated manifest). CI and the container build would then use a
dependency set nobody reviewed, and nothing would fail.

## Options

1. **Do nothing** — rely on discipline; drift goes unnoticed.
2. **Lockfile drift check** — snapshot `manifest.toml`, run
   `gleam deps download`, fail if the file changed; cheap, works locally
   and in CI regardless of git state.
3. **Hermetic Nix build of dependencies** — fetch Hex tarballs as
   fixed-output derivations from the manifest checksums and build offline;
   fully hermetic but a lot of machinery for this project.

## Decision

Option 2. A `just deps-check` recipe copies `manifest.toml` aside, runs
`gleam deps download` and diffs the result. `just check` runs it first, so
CI (`nix develop --command just check`) enforces it without a workflow
change. It compares against the file on disk, not against git `HEAD`, so a
locally updated but not yet committed manifest passes.

Intentional dependency updates:

1. `gleam deps update` (all, within ranges), `gleam deps update <pkg>`, or
   edit `gleam.toml` / `gleam add <pkg>` followed by `gleam deps download`.
2. `just check`.
3. Review `git diff manifest.toml`.
4. Commit `gleam.toml` and `manifest.toml` together, e.g.
   `build(deps): bump wisp to 2.3.0`.

## Consequences

- Unreviewed dependency changes fail CI with a diff in the log.
- On failure locally, the regenerated manifest is left in place so it can
  be reviewed and committed.
- Builds still need Hex to be reachable; option 3 remains open if a fully
  hermetic build is ever required.

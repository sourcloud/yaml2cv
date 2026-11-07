# 0006. Apache-2.0 license and removal of legacy code

- Status: Accepted
- Date: 2026-11-07

## Context

The repository had no license, and the Python prototype will be replaced.

## Decision

- License the project under Apache-2.0 (permissive, explicit patent grant).
- Keep the Python prototype as a reference until the Gleam port reaches
  feature parity, then delete it. Git history preserves it; the example CV is
  kept as a test fixture and example.

## Consequences

- Contributions are accepted under Apache-2.0 (see CONTRIBUTING.md).

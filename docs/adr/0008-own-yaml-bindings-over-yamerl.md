# 0008. Own YAML bindings over yamerl

- Status: Accepted
- Date: 2026-11-07

## Context

Gleam has no native YAML parser. The Gleam wrapper `glaml` (3.0.2, latest at
the time) wraps the Erlang library `yamerl`, but its Erlang FFI returns error
terms that do not match its own Gleam types: every YAML syntax error crashes
the caller with a `CaseClause` instead of returning `Error`. Syntax errors are
an everyday case for a CV editor.

## Options

1. **Own FFI over yamerl** — ~40 lines of Erlang plus a Gleam module; full
   control over the node and error types.
2. **Keep glaml and patch around it** — depends on glaml internals.
3. **Keep glaml and wait for an upstream fix** — syntax errors crash requests
   meanwhile.

## Decision

Option 1. `src/yaml2cv/yaml.gleam` defines `Node` and `ParseError` and
binds `parse/1` to `src/yaml2cv_yaml_ffi.erl`, which calls
`yamerl_constr:string/2` with `detailed_constr` and converts the records.
yamerl is a direct dependency.

## Consequences

- One small Erlang module to maintain; a good, contained example of Gleam FFI.
- YAML node kinds yamerl may add through extensions (timestamps, binaries) are
  reported as unsupported rather than crashing.
- Denial-of-service hardening (input size, alias expansion) must happen
  before parsing, at the HTTP layer (M4).

# 0002. Use Gleam on the Erlang target

- Status: Accepted
- Date: 2026-11-07

## Context

The original prototype is a Python/Flask script. The rewrite is also meant
as a way to learn the BEAM virtual machine, while producing a professional,
deployable application.

## Options

1. **Elixir** — largest BEAM ecosystem (Phoenix, LiveView), mature tooling;
   dynamically typed.
2. **Gleam** — statically typed, small and consistent language, friendly
   compiler, good tooling (`gleam` CLI, formatter, LSP); smaller ecosystem.
3. **Erlang** — closest to OTP fundamentals, verbose for web work.

## Decision

Gleam, compiled to Erlang. Static types fit the core of the problem
(validating a structured document), and the language is small enough to learn
alongside the project while still giving access to OTP and the Erlang/Elixir
package ecosystem via Hex.

## Consequences

- Fewer ready-made libraries; we may need thin Erlang FFI wrappers.
- No behaviours or type classes: polymorphism is expressed with records of
  functions (relevant for ADR 0003).
- The JavaScript target is available later if we want shared client code.

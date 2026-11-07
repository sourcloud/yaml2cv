# 0009. Typst renderer: execution, limits and themes

- Status: Accepted
- Date: 2026-11-07

## Context

ADR 0003 chose Typst as the first rendering backend. This ADR settles how
Typst is invoked, how its resource use is bounded, how themes are packaged
and what the first theme looks like.

## Decision

**Execution.** Each render gets a fresh temporary directory. The theme
directory is copied into it and the CV JSON (ADR 0003) is written as
`cv.json`. `typst compile` is started through an Erlang port:

```sh
typst compile --root <tmp> --ignore-system-fonts cv.typ cv.pdf
```

The PDF is read back and the temporary directory is always removed.

**Limits.**

- A compile that exceeds the timeout (default 10 s, configurable) is killed
  at the OS level and reported as a timeout.
- A concurrency limiter caps parallel compiles (default: number of BEAM
  schedulers). It is an OTP actor wrapping any renderer, so it is reusable
  for future backends and testable with a fake renderer.

**Fonts.** Only fonts embedded in the Typst binary are used
(`--ignore-system-fonts`): New Computer Modern, Libertinus Serif, DejaVu Sans
Mono. Output is identical on every machine and no font files are shipped.

**Themes.** A theme is a directory `priv/themes/<name>/` with an entry file
`cv.typ` that loads `json("cv.json")`. Adding a theme means adding a
directory and a `Theme` variant.

**First theme: `classic`.** Inspired by moderncv classic, set in New
Computer Modern: large name, title and contact line in the header; each
section headed by its name followed by a rule in the accent colour; entries
laid out with the timespan in a narrow left column and title, organisation,
location and bullets in the right column; skills as name/level pairs.

## Consequences

- Needs the `typst` executable at runtime; its path is configurable.
- Process killing on timeout relies on the OS pid of the port (Unix `kill`).
- Typst package imports are never used by themes; user content cannot add
  any because it is data, not markup.

# 0003. Pluggable renderer with a Typst backend

- Status: Accepted
- Date: 2026-11-07

## Context

The prototype renders a Jinja2 template into LaTeX (moderncv) and runs
`pdflatex`. Problems:

- User text is interpolated into LaTeX source without escaping, so CV content
  can execute TeX commands (e.g. `\input{/etc/passwd}`).
- A TeX Live installation makes the container image ~2 GB; compiles are slow.

## Options

1. **Keep LaTeX/moderncv** — familiar output, heavy and injection-prone.
2. **Typst only** — single small binary, millisecond compiles, can read JSON
   natively; needs a new template.
3. **Renderer abstraction, Typst first** — same as 2, but keep the door open
   for other backends (LaTeX, HTML) later.

## Decision

Option 3. The core defines a renderer as a record of functions, roughly
`Renderer(name: String, render: fn(Cv) -> Result(BitArray, RenderError))`.
The first implementation is Typst:

- The validated CV is serialised to JSON and written next to the template in
  a per-request temporary directory; the template loads it with
  `json("cv.json")`. User content is **data, never markup**.
- `typst compile` runs with `--root` set to that directory and with bundled
  fonts only (`--ignore-system-fonts --font-path`) for sandboxing and
  reproducible output, under a timeout. The directory is always removed.

## Consequences

- The moderncv look is not reproduced; themes are rewritten in Typst.
- A `typst` binary is a runtime dependency (dev shell and container).
- Tests can inject a fake renderer; one integration test exercises Typst.

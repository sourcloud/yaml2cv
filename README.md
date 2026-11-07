# yaml2cv

Keep your CV as structured data, get a typeset PDF back.

yaml2cv takes a CV written in a small YAML schema, validates it and renders it
to PDF using [Typst](https://typst.app). It ships as a lightweight, stateless
web application with an HTTP API and a browser-based editor with live
validation and preview.

> **Status:** rewrite in progress. The project is being ported from a
> Python/Flask + LaTeX prototype to [Gleam](https://gleam.run) on the BEAM.
> See [the roadmap](#roadmap) and the [architecture decision records](docs/adr/).

## Example

```yaml
cv:
  theme: classic
  color: blue
  title: My personal CV

personal:
  firstname: John
  lastname: Doe

contact:
  email: john.doe@example.com

sections:
  - name: Professional Experience
    entries:
      - timespan: since 2020
        title: Example Job
        organization: Example Company
        city: Example City
        bullets:
          - This will be rendered as a bullet point
```

The schema is not final yet; it is being redesigned as part of the port.

## Quickstart

_Coming soon._ The development environment is provided by a Nix flake:

```sh
direnv allow     # or: nix develop
gleam test
```

## Roadmap

- [x] M0 — Repository hygiene: license, docs, workflow, ADRs
- [ ] M1 — Dev environment (Nix flake), Gleam scaffold, CI
- [ ] M2 — Domain model and YAML validation
- [ ] M3 — Pluggable renderer with Typst backend
- [ ] M4 — HTTP API
- [ ] M5 — Browser editor (htmx)
- [ ] M6 — Container image, removal of the legacy Python app, v0.1.0

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Copyright 2022–2026 Sascha Scheid.

Licensed under the [Apache License, Version 2.0](LICENSE).

# 0011. Browser editor and UI component library

- Status: Accepted, PNG preview superseded by 0019, preview debounce by 0040, validate request by 0041
- Date: 2026-11-07

## Context

M5 adds a browser editor on top of the stateless API (ADR 0004, 0010):
users edit YAML, see validation errors while typing and a live preview of
the rendered CV. The UI should look professional while staying small and
dependency-free.

## Decision

**Editor.** A plain `<textarea>` (small script for Tab indentation),
preloaded with the example CV. htmx drives three form-encoded endpoints:

- `POST /editor/validate` — on input, debounced 400 ms: returns an HTML
  fragment with the validation status and error list.
- `POST /editor/preview` — on input, debounced 1 s, in-flight requests
  replaced (`hx-sync`): renders PNG pages at 110 ppi (at most 10 pages)
  and returns `<img>` tags with `data:` URIs, keeping the server stateless.
  An invalid document answers `204`, so the last good preview stays.
- `POST /editor/download` — plain form submit, returns the PDF as an
  attachment.

**Renderer.** The renderer record gains a second function for PNG pages
next to PDF, both going through the concurrency limiter.

**Design system.** Hand-written CSS in `priv/static/css/`, organised like a
component library:

- `tokens.css` — colours, spacing, type scale, radii, shadows as custom
  properties; dark mode through `prefers-color-scheme`.
- `base.css` — element defaults built only from tokens.
- `components/<name>.css` — one file per component, classes `ui-<name>`
  with BEM-style elements/modifiers (`ui-button--primary`).
- `app.css` — declares `@layer tokens, base, components, layout` and imports
  the files into their layers.

Each CSS component has a Gleam counterpart in `src/yaml2cv/web/ui/` that
builds its markup with `lustre/element` (used only as an HTML builder), so
markup and styles stay in sync. Components are snapshot-tested.

**Security.** Pages send a strict Content-Security-Policy (`'self'` only,
`data:` images); htmx and the editor script are vendored in
`priv/static/` and htmx's inline indicator styles are disabled.

## Consequences

- Preview responses are larger (~100 KB per page, base64) but need no cache.
- Live rendering raises Typst load per user; the limiter (ADR 0009) bounds it.
- No CSS or JS build step; adding a component means one Gleam module and one
  CSS file.

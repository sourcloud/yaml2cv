# 0024. Visual block editor next to the YAML source

- Status: Proposed
- Date: 2026-11-08

## Context

The editor is a plain YAML textarea (ADR 0011, 0021). Users who are not
comfortable with YAML want to build their CV from predefined blocks that
map one to one to the schema (ADR 0007), and switch to the raw YAML at any
time. The YAML must stay the source of truth and be copyable at any time.

yamerl does not keep comments or formatting, and there is no YAML emitter
yet. The UI is server-rendered with htmx, has no JS build step and a strict
CSP (ADR 0004, 0011).

## Options

Where the conversion runs:

1. **Server side, htmx** — Gleam turns YAML into blocks (HTML forms) and
   form posts back into YAML; one schema, no new client code beyond a few
   delegated handlers. Every edit is a round trip.
2. **Client side** — vendor a JS YAML library and build the blocks in JS;
   instant, but duplicates the schema in untested JS and goes against
   ADR 0004.

Comments and formatting: rewrite the YAML canonically on the first visual
edit; refuse visual mode when the YAML has comments; or rewrite on every
switch back.

Reordering: up/down buttons (plain posts) or drag and drop (more JS).

Documents that do not fully validate: require a valid CV before switching,
or accept anything that maps onto blocks.

## Decision

- Conversion runs on the server (option 1). `cv/draft` is a lenient model
  of the YAML structure: every scalar is a string, so missing or empty
  required fields are representable. `cv/draft/to_yaml` writes it back as
  canonical YAML (keys in schema order, empty optional keys left out,
  `kind` always written).
- Switching to visual mode posts the YAML to `POST /editor/visual`. Syntax
  errors, unknown keys, wrong node types, unknown style values and an
  unsupported `schema_version` cannot be mapped: the errors are listed and
  the editor stays in YAML mode. Missing required fields become empty
  inputs; the existing validation reports them.
- Every visual edit posts the block form to `POST /editor/visual/update`,
  which answers with the regenerated YAML; `editor.js` copies it into the
  textarea and fires `input`, so validation, preview, copy and download
  keep working on the textarea alone. Structural changes (add, remove,
  move up or down) also re-render the blocks.
- Switching to visual mode does not touch the YAML. The first visual edit
  rewrites it canonically, dropping comments, formatting and anchors; the
  visual pane says so.
- Blocks are reordered with up and down buttons. A section's kind is chosen
  when it is added and cannot be changed afterwards.

## Consequences

- No new dependency, vendored script or CSP change.
- Each visual edit costs a request; typing is debounced.
- Comments survive only as long as the user stays in YAML mode.
- The draft decoder and the emitter must follow every schema change; a
  round-trip test over the example catches drift.

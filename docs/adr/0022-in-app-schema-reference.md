# 0022. In-app schema reference

- Status: Accepted
- Date: 2026-11-08

## Context

Users of a deployed instance may not have access to the repository, where
the CV schema is only described in ADR 0007 and its amendments (ADR 0015,
0017). The editor needs a reference of every key and option.

## Options

1. **Gleam view with choices from the domain model** — the reference is a
   view in Gleam; theme, colour and paper choices and the default style come
   from `cv.gleam`, the documented keys are checked against the decoder.
2. **Markdown file rendered into the page** — one source readable on GitHub
   too, but needs a Markdown renderer or dependency.
3. **Annotated YAML example** — least code, but harder to scan and to keep
   complete.

For the overlay: a native modal `<dialog>` in the page, content fetched on
open, or a non-modal `popover`.

## Decision

Option 1, in a native modal `<dialog>` rendered inline with the editor page.

- `cv/decode` exports the keys each mapping accepts and the section kinds;
  the decoder uses these lists, and a test asserts the reference documents
  exactly them. `cv.default_style` holds the defaults for both.
- `web/schema_help` builds the reference from the new UI components
  `ui/dialog` and `ui/field_table`.
- A "Schema" button in the CV panel header opens the dialog via `editor.js`
  (`showModal`). It closes with its Close button (`<form method="dialog">`,
  no script), Escape, or a click on the backdrop.

## Consequences

- Adding a key to the decoder fails the test until it is documented.
- Descriptions are still hand-written and can be wrong in wording, but not
  incomplete.
- The page is a few kilobytes larger; no extra request or endpoint.

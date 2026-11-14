# 0042. Lean requests and no second wait in visual mode

- Status: Accepted
- Date: 2026-11-13

## Context

The visual editor (ADR 0024) feels much slower than the YAML editor. A block
edit waits 300 ms, posts the blocks to `/editor/visual/update`, copies the
returned YAML into the source field and fires `input` there, which waits
another 300 ms (ADR 0040) before the preview request (ADR 0041). Only the
preview request leaves the photo in the browser (ADR 0039): with the
900 × 1157 test photo each visual update uploads about 206 KB and downloads
about 145 KB, against about 8 KB and 1 KB with the placeholder.

## Options

1. **Placeholder for every editor request, and no second wait** — the
   editor script swaps the photo for its placeholder in every htmx request
   and back in every response; YAML coming from visual mode asks for the
   preview at once. Endpoints unchanged.
2. **As 1, and `/editor/visual/update` also returns status and preview** —
   one round trip per edit, but the visual endpoint renders, even for edits
   still queued behind others.
3. **Placeholder only** — keeps the second 300 ms wait.

## Decision

Option 1.

- The editor script replaces every acceptable photo URI (ADR 0039) in every
  field of every htmx request with its placeholder, and every placeholder
  in a response with the real photo before it is swapped in. This covers
  the YAML sent by the status line and the mode switch, and the
  `person.photo` field of the blocks. The PDF download and the language
  switch are plain form submits and still send the real photo.
- YAML regenerated from the blocks is copied into the source field with a
  `yaml-synced` event instead of `input`. The status line requests the
  preview on `yaml-synced` at once; typing in the source field keeps the
  300 ms delay. The line-number gutter follows both events.

## Consequences

- A block edit reaches the preview after about 300 ms and two small round
  trips instead of 600 ms and two round trips carrying the photo.
- The placeholder now also passes through the visual form parser and the
  YAML emitter; both copy the URI unchanged.
- Scripts listening for `input` on the source field no longer see edits
  made in visual mode; they listen for `yaml-synced` as well.

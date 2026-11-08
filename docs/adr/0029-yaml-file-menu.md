# 0029. Copy, download and import the YAML from one menu

- Status: Proposed
- Date: 2026-11-08

## Context

The service keeps nothing between requests (ADR 0010), so the YAML in the
editor is the user's only copy of their work. Until now the only way to take
it away was **Copy YAML**, which needs a second application to paste into,
and there was no way to bring a saved CV back except pasting it. The CV
panel header already holds the mode switch, the schema reference and the
copy button; it should not grow further.

## Options

Placement:

1. **One menu button** replacing Copy YAML, listing Copy, Download and
   Import — the header keeps its number of buttons.
2. **Split button** — Copy stays one click, an arrow opens Download and
   Import; a more complex control.

Mechanism:

1. **In the browser** — download from a `Blob` of the editor text, import
   with the File API into the editor. No new endpoints; the file never
   leaves the browser. Needs JavaScript, as copying already does.
2. **Server endpoints** — return the posted YAML as an attachment and accept
   a multipart upload. Works without JavaScript, but adds two endpoints and
   a round trip of the whole CV.

Import guard: replace directly but undoably, or confirm first.

## Decision

A **YAML** menu button in the CV panel header (`ui-menu`, a menu button
following the WAI-ARIA menu button pattern) with three items:

- **Copy** — as before; the "Copied" feedback shows on the menu button.
- **Download .yaml** — saves the editor text as `cv.yaml` (matching
  `cv.pdf`), built in the browser.
- **Import .yaml…** — reads a picked `.yaml`/`.yml` file in the browser
  and replaces the editor text through `insertText`, so undo brings the old
  text back. Files above the request body limit (`MAX_BODY_BYTES`) are
  rejected, since the server would refuse to validate or render them. In
  visual mode the editor shows the YAML, then asks for the blocks of the
  imported document again; YAML that does not fit the blocks stays in YAML
  mode with its errors.

In visual mode, block edits still waiting for the debounce are written into
the YAML before copying or downloading (as for the language switch).

## Consequences

- Users can save and restore their CV without a clipboard round trip;
  statelessness is unchanged and no endpoint is added.
- Copying, downloading and importing need JavaScript; without it the YAML
  can still be selected and copied by hand.
- `ui-menu` is available for further header actions without adding buttons.

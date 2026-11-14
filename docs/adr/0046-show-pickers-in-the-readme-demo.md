# 0046. Show select lists and the file picker in the README demo

- Status: Proposed
- Date: 2026-11-13

## Context

The README demo (ADR 0044) is recorded in headless Chromium. Native
`<select>` lists and the operating system's file chooser are drawn outside
the page, so the video shows a select changing its value and a photo
appearing without the list or dialog that chose them.

## Options

For the select lists:

1. **Expand in the page** — the script shows a list box with the select's
   real options below it, points at the chosen one, then sets the value.
2. **Drawn dropdown overlay** — closer to a native popup, but an element
   that exists only in the recording.
3. **Record a visible browser from the screen** — true native popups, but
   needs screen-recording permission, looks different on every machine and
   is no longer one reproducible command.

For the file chooser: a mock file dialog in the page, a caption only, or
leaving it as it is.

## Decision

Option 1 for the select lists and a mock file dialog for the photo.

- `record.mjs` places a `<select size=…>` with the original's options right
  below it, moves the pointer to the chosen option, selects it, removes the
  list and sets the original select, which then behaves as before.
- After a click on the photo button, the script shows a small file dialog
  in the page listing the portrait with its thumbnail. The pointer selects
  it and clicks Open; then the real file is handed to the file chooser
  Playwright intercepted.
- Both are added by the recording script only; the application is
  unchanged.

## Consequences

- The demo reads as a sequence of visible choices, at the cost of a few
  seconds of length and some GIF size.
- The list box and the file dialog look like neither macOS nor Windows
  dialogs; they show the step, not a specific platform.

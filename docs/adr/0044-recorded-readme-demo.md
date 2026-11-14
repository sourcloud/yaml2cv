# 0044. Record the README demo with a script

- Status: Proposed
- Date: 2026-11-13

## Context

The README describes the editor in prose only. A short animation of the main
interactions (editing YAML with a live preview, a validation error, the
visual mode, switching theme, adding a photo, changing the colour,
downloading the PDF) shows what the
application does faster than text. The UI keeps changing, so a demo recorded
by hand would go stale and be tedious to redo.

## Options

1. **Hand-made screen recording** — no tooling; cannot be reproduced and
   drifts from the UI.
2. **Scripted browser recording** — Playwright drives the editor of a running
   server and records a video; ffmpeg turns it into a GIF. Reproducible with
   one command; adds Node and a browser as development-only tools.
3. **Terminal recorders (vhs, asciinema)** — reproducible, but cannot show a
   browser UI.

## Decision

Option 2. `dev/demo/record.mjs` drives the editor in headless Chromium at
1280×720 in English with a dark colour scheme and draws a visible pointer,
since headless recordings have none. `just demo-gif [url]` records against a
running server and converts the video with ffmpeg (12 fps, 900 px wide,
128-colour palette) to `docs/demo.gif`, which the README embeds.

- Playwright is pinned in `dev/demo/package.json` and `package-lock.json`;
  its browser is downloaded by Playwright, not Nix.
- Node and ffmpeg come from a separate `devShells.demo` in the flake, so the
  default shell and CI stay as they are.
- gifski would give smaller GIFs but did not build on macOS from nixpkgs at
  the time; ffmpeg's palette filters are good enough.
- The photo is an illustrated portrait the script draws as SVG and saves as
  JPEG before recording, so the demo shows no real person and adds no image
  to the repository.
- `dev/demo/` is excluded from the container build context.

## Consequences

- After visible UI changes, rerun `nix develop .#demo -c just demo-gif` with
  `just run` in another terminal and commit the new GIF.
- The script selects elements by ids, data attributes and English labels; a
  change to those breaks the recording, not the application.
- The GIF (about 3–3.5 MB) lives in the repository; each re-recording adds a
  new binary to history.

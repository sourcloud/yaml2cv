# 0021. Editor line numbers and jump to error

- Status: Accepted
- Date: 2026-11-08

## Context

YAML syntax errors report a line and column, but the editor (ADR 0011) is a
plain `<textarea>` without line numbers, so users have to count lines to find
the problem.

## Options

1. **Line-number gutter next to the textarea** — a small addition to the
   vendored `editor.js`; keeps the plain textarea, no dependency or build step.
2. **Code editor library** (e.g. CodeMirror) — line numbers, highlighting and
   error markers, but much larger, needs bundling and replaces the textarea
   chosen in ADR 0011.

Line numbers only match visual rows when long lines do not wrap. Keeping
soft wrap would require measuring each line's wrapped height in a hidden
mirror element.

## Decision

Option 1, with soft wrap turned off (`wrap="off"`): long lines scroll
horizontally, one row per source line, as in most code editors.

- `ui/code_area` renders a gutter (`aria-hidden`) beside the textarea, already
  numbered for the initial value so it is correct before scripts run.
  `editor.js` renumbers it on input and keeps its scroll position in sync.
- Syntax errors in the problem list carry their position. Their location is a
  button that moves the cursor to that line and column in the editor. Schema
  errors have only a path and stay plain text.

## Consequences

- The gutter and the textarea must share font, size, line height and vertical
  padding; both take them from the same CSS rules.
- Without JavaScript the gutter shows the initial line count only and the
  location buttons do nothing.
- Schema errors cannot jump yet; that would need source positions in the
  decoded YAML nodes.

# 0015. Minimal single-column theme

- Status: Accepted, skills layout amended by 0016, timespans and skills superseded by 0037
- Date: 2026-11-07

## Context

The only theme, `classic` (ADR 0009), uses a two-column layout with the
timespan in a narrow left column and a coloured bar in front of each section
heading. Some users want a quieter, more reduced look that uses the full page
width for content.

## Options

1. **Make `classic` configurable** (layout switches) — one file, but the
   theme grows options and loses its moderncv character.
2. **Add a second theme** — a new directory and a `Theme` variant, as
   anticipated by ADR 0009; themes stay simple and independent.

## Decision

Add a second theme, `minimal`. ADR 0007's `style.theme` accepts
`classic` (default) and `minimal`.

- Single column, set in Libertinus Serif (embedded in Typst, ADR 0009).
- Header: name in black, title muted below it, contact items on one line.
- The accent colour (`style.color`) is used sparingly: only section headings,
  in letter-spaced small caps, followed by a thin hairline rule in the accent
  colour.
- Entries: title on the left and timespan flush right on the same line;
  organisation and location below in muted italics; bullets underneath.
  Entries are not split across pages.
- Skills: name on the left, level muted on the right, one per line.
- Text sections: a plain paragraph.

## Consequences

- Each theme is a self-contained directory, so shared pieces such as the
  accent palette are duplicated rather than imported.
- Every theme is covered by the renderer tests, including the check that user
  content is treated as text.

# 0037. One reading order in every theme

- Status: Accepted
- Date: 2026-11-13

## Context

Text extractors used by applicant tracking systems and AI screening read a
PDF by the position of its text, not by its structure tree (ADR 0035). They
group text into columns and lines by the gaps between glyphs. Several themes
set related text side by side with wide gaps, and the extracted text falls
apart:

- `minimal` sets the timespan flush right next to the entry title
  (ADR 0015); pdfminer collects all timespans at the end of the document.
- `spotlight` and `cover` set timespans in a narrow left column
  (ADR 0030); pdfminer reads that column, together with the section titles
  that align with it, apart from the entries, so titles end up in the wrong
  section.
- `studio` sets contact details and skills sections in a sidebar next to
  the main column (ADR 0030); pdftotext interleaves sidebar and main lines.
- Skills grids put names and levels in separate columns (`minimal`,
  `studio`, `spotlight`; ADR 0016), so extractors read all names, then all
  levels.

## Options

Timespans in `minimal`, `spotlight` and `cover`:

1. **Stacked above the title** in the text column, as `studio` does.
2. Inline after the title.
3. Keep the columns and recommend `classic` and `studio` for portals.

`studio`'s sidebar:

1. **Only the photo or initials stay in the sidebar**; contact details go
   under the name and skills sections into the main column.
2. Keep the sidebar.
3. Keep contact details beside the name, move only skills sections.

Skills: **name and level on one line**, or keep the grid with a narrower
gap. For `classic`: **the same**, or keep its name and level columns.

Tests: **pdftotext and pdfminer**, or pdftotext only.

## Decision

Text that belongs together is set in one column, in reading order, so that
extractors cannot split it.

- **Timespans** in `minimal`, `spotlight` and `cover` are a small line
  above the entry title, like `studio`. This replaces the flush-right
  timespans of ADR 0015 and the timespan column of ADR 0030.
- **`studio`**'s coloured column keeps the photo or initials only. Contact
  details follow the name and title in the main column; skills sections are
  ordinary sections in document order. This amends the `studio` layout of
  ADR 0030.
- **Skills** read `name – level` on one line, the level in muted text, in
  every theme; one skill per line. In `classic` they move from the
  timespan column into the text column, because pdftotext split short
  names from their level. Skills sections are laid out one after another,
  not side by side. This replaces the skills grids of ADR 0015, ADR 0016
  and ADR 0030.
- `classic` keeps its timespan column for entries: its timespans share the
  baseline and size of the title, close enough that extractors read one
  line. The tests hold it to that.
- Python with **pdfminer.six** joins the dev shell next to poppler-utils
  (ADR 0035), for dev and CI only. Tests render every theme and check with
  both extractors that each timespan is next to its title, each skill
  reads with its level, sections appear in document order, and contact
  details appear before the first section.

## Consequences

- The extracted text of every theme follows the document, whichever of the
  two extractors reads it; other extractors are likely but not guaranteed
  to agree.
- `minimal`, `spotlight`, `cover` and especially `studio` look different.
  ADR 0033 allows that in a minor release; the release notes should show it.
- New themes must not set related text in separate columns; the tests
  cover every theme in `cv.themes`.
- The dev shell grows by a Python interpreter with one package.

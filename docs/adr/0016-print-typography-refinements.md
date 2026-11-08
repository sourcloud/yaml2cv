# 0016. Print typography refinements for both themes

- Status: Accepted
- Date: 2026-11-07

## Context

A review of `classic` (ADR 0009) and `minimal` (ADR 0015) against print
design practice found:

- `classic` section headings could be left alone at the bottom of a page.
- `minimal` set running text across the full 166 mm text width, about 100
  characters per line; 45–75 is the usual comfortable range.
- `minimal` placed skill levels flush right, far away from their names.
- Muted text (40–45 % grey) at 9.5 pt and in italics can print spotty on
  office laser printers.

Bleed is not needed: neither theme prints outside its margins. Ragged-right
text without hyphenation stays, as it suits short bullets and narrow columns.

## Decision

- `classic`: section headings stick to the following content.
- `minimal`: paragraphs, bullets and organisation lines are limited to a
  13 cm measure (about 75–80 characters); titles and timespans keep the full
  width so timespans stay flush right.
- `minimal`: each skills section is one grid, name column as wide as the
  longest name, level next to it in muted text. This replaces the skills
  layout in ADR 0015.
- Both: muted text is 35 % grey.

## Consequences

- Layout changes are visible to existing users of both themes.
- Open, not decided: vertical spacing derived from the line height, pure
  black (`luma(0%)`) for the `black` accent, a larger bottom margin, and a
  paper size option (which would need a schema change).

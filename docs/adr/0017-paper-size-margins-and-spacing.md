# 0017. Paper size, margins, spacing and black

- Status: Accepted
- Date: 2026-11-07

## Context

ADR 0016 left four print points open: every CV is A4, which does not suit
readers in the US and Canada; top and bottom margins are equal, which makes
the text block look low on the page; vertical gaps use many unrelated values;
and the `black` accent is RGB black, which print workflows may turn into a
four-colour black that looks fuzzy on small text.

## Options

For the paper size:

1. **`style.paper`: `a4` | `letter`** — covers Europe and North America,
   validated like `style.color`.
2. **More sizes (`a5`, `legal`, …)** — rarely used for CVs, more to test.
3. **A4 only** — no schema change.

## Decision

- **Paper size.** Schema version 1 (ADR 0007) gains an optional key:

  ```yaml
  style:
    paper: a4    # optional, default a4; one of: a4, letter
  ```

  Adding an optional key keeps every existing document valid, so
  `schema_version` stays 1. Themes map `letter` to Typst's `us-letter`.
- **Margins.** The bottom margin is 5 mm larger than the top one:
  `classic` 2.0 cm / 2.5 cm, `minimal` 2.2 cm / 2.7 cm; sides unchanged.
- **Spacing.** Each theme defines one unit, its paragraph leading (0.6 em).
  Gaps between list items, lines of an entry and skill rows are one unit,
  gaps between entries two units, gaps before section headings three units.
  The header is display type and keeps its own spacing.
- **Black.** The `black` accent is `luma(0%)`, a pure single-ink black, in
  both themes.

## Consequences

- A paper-size choice in the editor or API is only possible through YAML;
  there is no separate parameter.
- Pages hold slightly less content than before.

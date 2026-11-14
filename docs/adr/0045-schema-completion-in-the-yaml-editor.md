# 0045. Complete schema keys and values in the YAML editor

- Status: Accepted
- Date: 2026-11-13

## Context

Writing a CV in the YAML editor means looking up key names and allowed
values in the schema reference (ADR 0022). Code editors offer these while
typing. The editor is a plain `<textarea>` (ADR 0011) with a line-number
gutter (ADR 0021); a code editor library was rejected there for its size and
build step.

## Options

1. **Completion list on the plain textarea** — the page carries the schema
   as JSON; `editor.js` reads the mapping around the cursor from the
   indentation of the lines above and offers its keys, or the allowed values
   after a key with a fixed set. No dependency, but only block-style YAML is
   understood.
2. **CodeMirror 6 with a YAML schema completion source** — complete and
   robust, but needs bundling, about 150 KB more script, and replaces the
   textarea, the gutter and jump to error (supersedes ADR 0011, 0021).
3. **`<datalist>`** — works only on `<input>`, not on a textarea.

## Decision

Option 1, with the explanations from the schema reference and without
inserting skeletons of nested content.

- `web/schema_help` holds the schema as plain data (mappings with their
  path, keys, requirement, explanation and allowed values with the default).
  The reference dialog and the completion data are both built from it, so
  the existing test against the decoder's key lists covers both.
- The editor textarea carries the data as JSON in `data-completions`, in the
  page's locale.
- `editor.js` finds the cursor's context from the indentation, list dashes
  and keys of the lines above it:
  - at the start of a key, it offers the keys of that mapping not yet used
    in it;
  - after `key:` with a fixed set of values (`theme`, `color`, `paper`,
    `photo_shape`, `kind`), it offers those values;
  - only at the column of the mapping's keys, which its first key sets
    (column 0 at the root): a line indented differently offers nothing.
- The list opens while typing a key or value and with Ctrl+Space. Arrow
  keys move, Enter or Tab insert, Escape closes; a click on an option
  inserts it. The highlighted option's requirement and explanation, or for a
  value whether it is the default, show below the list.
- Inserting a key writes `key: `, or `key:` when its value is a nested
  mapping or list. Nothing else is inserted.
- Enter keeps the indentation of the current line, counting list dashes
  as spaces so the next key lines up with the item's first key, and adds
  one level after a line that opens a block (`key:`, `key: |`, `key: >`).
  With the list open, Enter inserts the option instead.
- The textarea refers to the list with `aria-controls`,
  `aria-autocomplete="list"` and `aria-activedescendant`.

## Consequences

- Flow style (`{…}`, `[…]`), anchors, block scalar content and quoted keys
  get no completions; they still work as before.
- Keys and values offered can never be ones the decoder rejects, and a new
  key appears in the completions once it is documented.
- The editor page grows by a few kilobytes of JSON per locale.
- The context logic in `editor.js` has no automated tests, like the rest of
  the script; it is checked in the browser.

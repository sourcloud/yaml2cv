# 38. Explain fields in an overlay and name defaults plainly

- Status: Accepted
- Date: 2026-11-13

## Context

Some visual editor labels carried their explanation in parentheses, such as
"Language (code such as en or de)", which makes labels long and uneven. The
style selects offered the default as an extra first option, "Default (blue)",
followed by the same value again ("blue"), so the default appeared twice.

## Options

1. **Info button with a native popover** — a small "i" button next to the
   label opens an overlay with the explanation; `popover` and
   `popovertarget` need no script and survive htmx swaps.
2. **Info button opening a `ui-dialog`** — reuses the modal dialog, but
   needs `editor.js` and one dialog per field.
3. **Tooltip on hover** — not reachable on touch devices.

For the selects: show the default under its own name as the option with the
empty value (which leaves the key out of the YAML), or drop the empty option
and always write the chosen value.

## Decision

Option 1. Labels stay short; an explanation goes into an overlay opened by
an info button (`field.text_with_info`). The button sits outside the
`<label>`, which is linked to the input by id (`field-<name>`), because a
button inside a label would become its control.

Selects list every value once. The default is shown under its own name and
keeps the empty value, so choosing it omits the key as before; a value
equal to the default also selects that option.

## Consequences

- Choosing the default in the visual editor removes an explicit default
  such as `color: blue` from the YAML; the rendered CV is the same.
- Further fields can get explanations by adding a text and switching them
  to `field.text_with_info`.

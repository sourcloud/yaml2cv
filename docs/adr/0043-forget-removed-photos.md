# 0043. Forget a removed photo in the editor script

- Status: Accepted
- Date: 2026-11-13

## Context

To swap the photo for its placeholder and back (ADR 0039, 0042), the editor
script keeps the last four photos in memory. A photo removed with the
visual editor's remove button stayed there until newer photos pushed it out
or the page was reloaded.

## Options

1. **Clear the cache on remove** — the script holds no photo the user has
   taken out. A request still in flight may show the grey placeholder until
   the next preview, which follows right away.
2. **Keep the cache** — no visible effect, but the photo outlives the
   user's intent to remove it.

## Decision

Option 1. The remove button clears both maps of the photo cache before
the photo field is emptied.

## Consequences

- After a removal the script keeps no photo; the text area's undo history
  is the browser's and still holds the old YAML.
- Deleting the photo line in the YAML source does not clear the cache; the
  photo stays in memory until replaced by newer ones or the page closes.

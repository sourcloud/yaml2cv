# 0007. CV schema version 1

- Status: Accepted, language key added by 0036
- Date: 2026-11-07

## Context

The prototype schema wraps everything in `cv_data:`, splits names and
addresses into fixed fields, treats languages as a special top-level block,
and is not validated at all: missing or misspelled keys silently render as
empty LaTeX arguments. The rewrite needs a schema that is easy to write by
hand, validated strictly, and able to evolve.

## Decision

A flat document with an explicit version. Unknown keys and wrong types are
errors; all errors are collected and reported together, each with a path such
as `sections[1].entries[0].title`.

```yaml
schema_version: 1          # required, must be 1

style:                     # optional
  theme: classic           # optional, default classic; one of: classic
  color: blue              # optional, default blue; one of: black, blue,
                           # burgundy, green, grey, orange, purple, red

person:                    # required
  name: John Doe           # required
  title: Software Engineer # optional
  address: 1234 Main Street, 98765 Example City  # optional

contact:                   # optional
  email: john.doe@example.com   # optional
  phone: 0123 4 56 78 90        # optional
  website: https://example.com  # optional
  links:                        # optional
    - label: GitHub             # required
      url: https://github.com/johndoe  # required

sections:                  # required, may be empty
  - name: Professional Experience   # required
    kind: entries                   # optional, default entries
    entries:                        # required for kind entries
      - timespan: since 2020        # required
        title: Example Job          # required
        organization: Example Company  # optional
        location: Example City      # optional (was `city`)
        bullets:                    # optional
          - Did something useful

  - name: Languages
    kind: skills
    items:                          # required for kind skills
      - name: English               # required
        level: Proficient           # optional

  - name: About me
    kind: text
    text: Free-form paragraph.      # required for kind text
```

Details:

- Text fields accept YAML strings, integers and floats (so `timespan: 2021`
  works); booleans, lists and mappings are rejected.
- Text fields must not be empty after trimming whitespace.
- A YAML syntax error is reported with line and column.
- Exactly one YAML document per input.

## Consequences

- Old `cv_data:` files no longer validate; the example CV is migrated by hand.
  A converter is not planned unless requested.
- `schema_version` lets a later version add a migration step.
- New section kinds (e.g. publications) can be added without breaking
  existing documents.

# 0036. CV language and PDF metadata about the candidate

- Status: Accepted
- Date: 2026-11-08

## Context

ADR 0035 made the PDF text readable for applicant tracking systems and AI
screening. Two gaps remain:

- **Language.** Every theme sets `lang: "en"`. A German CV is marked as
  English in the PDF (`/Lang`, `dc:language`), which misleads language
  detection, and Typst hyphenates and sets quotes for the wrong language.
  The schema has no way to state the language.
- **Metadata.** ADR 0018 fills the PDF Subject with
  `Generated with yaml2cv <version> (<url>)` and Keywords with `yaml2cv`.
  Software that reads the metadata learns about the tool, not about the
  candidate.

## Options

Where the language is stated:

1. **A top-level `language` key** — it describes the content, not its look.
2. `style.language` — grouped with theme, colour and paper.

Which languages are accepted:

1. **Any two-letter ISO 639-1 code**, checked for its form only.
2. A fixed list such as `en` and `de`.

Editor support: **a field in the visual editor and an entry in the schema
reference**, or the schema reference only.

Subject: **`person.title`**, name and title, or keep the generator text.

Keywords: **skill names and a short credit `yaml2cv <version>`**, the
credit with the project URL only, or both.

## Decision

- **Language.** CV schema version 1 gains an optional top-level key
  `language`, after `schema_version`. Its value is a two-letter lowercase
  ISO 639-1 code (`en`, `de`, `fr`, …); anything else is an error
  ("expected a two-letter language code such as en or de"). It defaults to
  `en`, today's behaviour. The decoder checks the form, not a list, so any
  language Typst supports works without a release. The code is passed to
  the renderer in `cv.json` as `language`, and every theme sets
  `text(lang: cv.language)`.
- **Editor.** The visual editor shows the language as a text field next to
  the other document settings, and the schema reference documents it, in
  English and German (ADR 0022, ADR 0024, ADR 0025).
- **Subject** is `person.title`; without a title there is no Subject.
- **Keywords** are the item names of all skills sections, in document
  order and without duplicates, followed by `yaml2cv <version>`. The
  service builds the credit from the OTP application version and passes
  it as `--input generator=…`, as before (ADR 0018). The project URL is no
  longer part of the PDF metadata.
- **Title** and **Author** stay the person's name.

This supersedes the Subject and Keywords decision of ADR 0018; its way of
passing the version to Typst stays. Adding an optional key is allowed in a
minor release (ADR 0033).

## Consequences

- CVs can state their language; PDFs report it in `/Lang` and XMP, and
  Typst hyphenates and quotes accordingly.
- A CV that uses `language` is rejected by servers older than this change,
  as ADR 0033 accepts for new optional keys.
- An unknown but well-formed code such as `xx` passes validation; Typst
  then falls back to its defaults for hyphenation.
- Anyone holding a PDF can still see that yaml2cv produced it and which
  version, but no longer finds a link to the project in the metadata.
- New themes must set `lang`, `description` and `keywords` as described.

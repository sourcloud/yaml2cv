# 0018. Mark generated PDFs with yaml2cv metadata

- Status: Accepted
- Date: 2026-11-07

## Context

Someone inspecting a PDF (document properties, `pdfinfo`, `exiftool`) cannot
tell that it was produced by yaml2cv. Typst writes the PDF `Creator` /
`xmp:CreatorTool` field itself (`Typst <version>`) and offers no way to change
it, but themes control title, author, subject (`description`) and keywords
through `set document`.

## Options

What to state:

1. **Name, version and project URL** — traceable to the exact release and
   source; reveals which release a server runs.
2. **Name and version.**
3. **Name only.**

Where the version comes from:

1. **The OTP application version** (`vsn`, built from `gleam.toml`).
2. **An environment variable** set in the image — overridable, but can drift.

## Decision

- Every rendered PDF has the subject
  `Generated with yaml2cv <version> (https://github.com/sourcloud/yaml2cv)`
  and the keyword `yaml2cv`. `Creator` stays as Typst writes it.
- The version is read at start-up from the OTP application `vsn`. The
  configuration builds the subject text and hands it to the Typst renderer,
  which passes it to every compile as `--input generator=<text>`.
- Themes read it with `sys.inputs.at("generator", default: none)`. It is set
  by the service, not by the CV, so it stays out of `cv.json` (ADR 0003).

## Consequences

- Anyone holding a PDF can see which yaml2cv release produced it.
- The renderer configuration gains a `generator` field; tests can fake it.
- New themes must set `description` and `keywords` in `set document`.

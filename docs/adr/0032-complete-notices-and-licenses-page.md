# 0032. Complete third-party notices and a licenses page

- Status: Accepted
- Date: 2026-11-08

## Context

ADR 0013 generates `THIRD_PARTY_NOTICES.md` and `licenses/` from the
packages in the Erlang shipment only. Assets committed to `priv/` — the
Inter fonts (SIL Open Font License 1.1, ADR 0030) and htmx (0BSD) — ship
with their license files but are missing from the notices. Erlang/OTP and
Typst are mentioned in a fixed sentence without version or license.

The notices exist only inside the container image. Users of a deployed
instance cannot see which third-party components it contains or read their
licenses.

## Options

Where the page gets its data:

1. **Generated JSON** — the generator also writes the notices, license texts
   included, as JSON; the application loads it at startup and renders it.
2. **Scan `licenses/` at request time** — no versions or license names.
3. **Generate a finished HTML file** — not localised, no page chrome.

Where vendored assets are declared: a TOML file in the repository, or a list
in the generator.

How the texts are shown: one page with collapsible texts, opened from the
footer in a dialog like the schema reference (ADR 0022); or one plain-text
response per license file.

## Decision

**Components.** `third_party.toml` in the repository root lists vendored
assets with name, version, SPDX license identifiers and license files. The
generator also accepts components on the command line
(`--component 'Name|version|License|file,file'`); the Containerfile passes
Erlang/OTP (version read from the build image, which is the runtime image)
and Typst (the pinned version, license files copied from the Typst stage).
The fonts compiled into the Typst binary come from `typst-assets`, whose
`NOTICE` Typst's own does not include; its `LICENSE` and `NOTICE` for the
matching version are committed under `third_party/typst-assets/` and listed
in `third_party.toml`. A test keeps its minor version in step with Typst.
All of them appear in `THIRD_PARTY_NOTICES.md` and `licenses/<slug>/` like
packages.

**JSON.** With `--json <path>` the generator writes the same components and
their license texts as JSON. The image build writes it to the application's
`priv/notices.json`; `gleam run` has none.

**Page.** The application loads `priv/notices.json` at startup; a missing
file means an empty list, an invalid one fails the start. `GET /licenses`
renders an HTML page: yaml2cv's own license and source link, then one
collapsible `<details>` per component with its license texts. Without the
JSON the page says the notices are generated when the image is built.

**Footer and dialog.** The footer (ADR 0031) gets a "Licenses" link to
`/licenses`. With htmx loaded, clicking it opens a modal dialog (ADR 0022)
and fetches the page body as a fragment (`HX-Request` header) into it, so
the editor page does not carry all license texts. Without JavaScript the
link opens the page.

This amends ADR 0013.

## Consequences

- Updating Inter or htmx means updating `third_party.toml` too; the
  generator fails the image build when a listed license file is missing.
- Every page links to the licenses; the texts are loaded only on demand.
- The application keeps the license texts in memory (some hundred KB).

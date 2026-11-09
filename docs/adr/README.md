# Architecture decision records

Each significant design decision is recorded here, one file per decision,
using [`0000-template.md`](0000-template.md). See [AGENTS.md](../../AGENTS.md)
for the process.

| ADR | Title | Status |
| --- | ----- | ------ |
| [0001](0001-record-architecture-decisions.md) | Record architecture decisions | Accepted |
| [0002](0002-use-gleam-on-the-erlang-target.md) | Use Gleam on the Erlang target | Accepted |
| [0003](0003-pluggable-renderer-with-typst-backend.md) | Pluggable renderer with a Typst backend | Accepted |
| [0004](0004-server-rendered-web-app-with-wisp-and-htmx.md) | Server-rendered web app with Wisp and htmx | Accepted |
| [0005](0005-nix-flake-dev-environment.md) | Nix flake development environment | Accepted |
| [0006](0006-license-and-legacy-code.md) | Apache-2.0 license and removal of legacy code | Accepted |
| [0007](0007-cv-schema-version-1.md) | CV schema version 1 | Accepted |
| [0008](0008-own-yaml-bindings-over-yamerl.md) | Own YAML bindings over yamerl | Accepted |
| [0009](0009-typst-renderer-execution-and-themes.md) | Typst renderer: execution, limits and themes | Accepted |
| [0010](0010-http-api.md) | HTTP API, configuration, limits and logging | Accepted |
| [0011](0011-browser-editor.md) | Browser editor and UI component library | Accepted, PNG preview superseded by 0019 |
| [0012](0012-colour-theme-switch.md) | Colour theme switch | Accepted |
| [0013](0013-container-image-and-release.md) | Container image, third-party notices and releases | Accepted |
| [0014](0014-upgrade-to-erlang-otp-29.md) | Upgrade to Erlang/OTP 29 | Accepted |
| [0015](0015-minimal-theme.md) | Minimal single-column theme | Accepted |
| [0016](0016-print-typography-refinements.md) | Print typography refinements for both themes | Accepted |
| [0017](0017-paper-size-margins-and-spacing.md) | Paper size, margins, spacing and black | Accepted |
| [0018](0018-pdf-generator-metadata.md) | Mark generated PDFs with yaml2cv metadata | Accepted |
| [0019](0019-svg-preview-and-gzip.md) | SVG page previews and gzip responses | Accepted |
| [0020](0020-phone-home-observability.md) | Phone home: admin endpoint and UDP heartbeat | Accepted |
| [0021](0021-editor-line-numbers.md) | Editor line numbers and jump to error | Accepted |
| [0022](0022-in-app-schema-reference.md) | In-app schema reference | Accepted |
| [0023](0023-release-notes-from-conventional-commits.md) | Generate GitHub releases from Conventional Commits | Accepted |
| [0024](0024-visual-block-editor.md) | Visual block editor next to the YAML source | Accepted |
| [0025](0025-ui-localisation.md) | Localise the web UI | Accepted |
| [0026](0026-container-image-in-release-notes.md) | Reference the container image in the GitHub Release | Accepted |
| [0027](0027-lockfile-drift-check.md) | Fail CI when manifest.toml drifts from gleam.toml | Accepted |
| [0028](0028-profile-photo.md) | Profile photo inside the CV document | Accepted |
| [0029](0029-yaml-file-menu.md) | Copy, download and import the YAML from one menu | Accepted |
| [0030](0030-photo-centred-creative-themes.md) | Photo-centred themes for creative jobs | Accepted |
| [0031](0031-build-provenance-and-source-link.md) | Build provenance and a link to the source | Accepted |
| [0032](0032-complete-notices-and-licenses-page.md) | Complete third-party notices and a licenses page | Accepted |
| [0033](0033-stability-promise-for-1-0.md) | Stability promise for 1.0 | Accepted |
| [0034](0034-dependabot-for-github-actions.md) | Dependabot for GitHub Actions | Accepted |

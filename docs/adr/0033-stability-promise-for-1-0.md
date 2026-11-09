# 0033. Stability promise for 1.0

- Status: Accepted
- Date: 2026-11-08

## Context

All roadmap milestones up to M13 are done, and the next release could be
1.0.0. Releases already follow semver in name (ADR 0013, ADR 0023), but
nothing says which parts of yaml2cv a version number makes promises about.
People keep CVs as YAML files for years, call the HTTP API from scripts and
deploy the image with environment variables. They need to know what a minor
release may change and what only a major release may change. The answer
should not freeze parts that are still moving, such as the look of the
themes or the observability formats.

## Options

1. **Everything is public** — any visible change, including PDF layout,
   is breaking. Simple to state, but it freezes the themes and turns every
   typography fix into a major release.
2. **A named contract, everything else unstable** — list the interfaces
   that semver covers; anything not listed may change in a minor release.
3. **No promise** — stay on 0.x. Honest, but users get no guarantees.

## Decision

Option 2. From 1.0.0 on, a breaking change to the interfaces below needs a
new major version. Additions are minor, fixes are patch releases.

**Stable:**

- **CV schema version 1** (ADR 0007 and its amendments): keys, their
  types, required and optional keys, defaults, and the names of themes,
  colours, paper sizes and photo shapes. A CV that is valid for a 1.x
  release stays valid for every later 1.x release.
  - New optional keys and new allowed values (e.g. a new theme) may come
    in a minor release. Because unknown keys and values are errors, a CV
    that uses them is rejected by older servers.
  - Renaming or removing a key or value, making an optional key required,
    or changing what a value means needs `schema_version: 2` and a major
    release.
- **HTTP API v1** (ADR 0010): the endpoints `POST /api/v1/render`,
  `POST /api/v1/validate` and `GET /healthz`, the accepted request content
  types, the success responses, and the problem types: their slugs, status
  codes and extra members. New endpoints, new problem types and new
  members may come in a minor release; clients must ignore members they do
  not know.
- **Configuration**: the names and meaning of the environment variables
  in the README. A new variable may come in a minor release if its default
  keeps today's behaviour. Raising a limit's default is not breaking;
  lowering one is.

**Not covered**, so they may change in any release; release notes call
out notable changes:

- How a CV looks: layout, spacing, typography and colours within a theme.
  Theme names are stable; their appearance is not.
- The wording of error messages (`title`, `detail`, `message`). The
  `type` slug and the error `path` are stable.
- The browser editor: its pages, the `/editor/*` routes, its markup and
  the UI translations.
- The admin listener and the UDP heartbeat format (ADR 0020).
- The layout of the container image, other than the port and the
  environment variables.
- The Gleam modules. yaml2cv is an application, not a library.

**Support.** Only the latest release gets fixes, including security fixes;
there are no backports. Images are tagged `X.Y.Z`, `X.Y` and `X`, so
`ghcr.io/sourcloud/yaml2cv:1` follows every compatible release. There is
no `latest` tag; picking a major version is a deliberate choice.

## Consequences

- Before a schema, API or configuration change, check whether it is
  breaking under this ADR. A breaking change waits for 2.0 or is made in
  a backwards-compatible way.
- Commits that break the stable contract are marked with `!` or a
  `BREAKING CHANGE:` footer, so git-cliff lists them in the release notes
  (ADR 0023).
- Theme work can go on in minor releases. Users who need byte-identical
  PDFs pin an exact image digest.
- The release workflow publishes the major-version tag, which amends the
  tag list in ADR 0013.
- Observability and editor routes can be added to the contract later in a
  minor release; taking something out of it needs a major release.

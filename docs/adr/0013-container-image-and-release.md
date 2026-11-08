# 0013. Container image, third-party notices and releases

- Status: Accepted, base image amended by [0014](0014-upgrade-to-erlang-otp-29.md)
- Date: 2026-11-07

## Context

M6 makes the application deployable. The prototype's image installed all of
TeX Live (~2 GB). The new image must be small, reproducible, run as non-root,
and redistribute its dependencies in line with their licenses.

## Decision

**Image.** A multi-stage `Containerfile` (podman/docker):

- Build and runtime stages both use `erlang:27.3.4.19-alpine`, the same
  OTP release as the Nix dev shell.
- The build stage installs Gleam from the official release tarball, pinned
  by version and SHA-256, and runs `gleam export erlang-shipment`.
- The runtime stage adds Typst from the official static musl release, pinned
  by version and SHA-256 (same version as the dev shell), and runs the
  shipment as an unprivileged user on port 8000.
- Release checksums come from the digests GitHub publishes for the assets.

**Third-party notices.** A dev-only Gleam module (`dev/notices.gleam`, run
with `gleam run -m notices`) generates `THIRD_PARTY_NOTICES.md` and a
`licenses/` directory for every package in the shipment:

- package and version come from `manifest.toml` (mapping OTP application
  names such as `hpack` back to packages such as `hpack_erl`);
- license files (`LICENSE`, `LICENCE`, `NOTICE`, `COPYING`) are copied;
- packages without a license file but declaring Apache-2.0 get the standard
  Apache-2.0 text; any other package without license text fails the build.

The image adds the Erlang/OTP and Typst license texts. Notices live in
`/app/licenses`.

**CI and releases.** CI builds the image on every push and smoke-tests it
(`/healthz`, rendering the example CV). Tags `v*` publish the image to
`ghcr.io/sourcloud/yaml2cv` with semver tags, authenticated by
`GITHUB_TOKEN`.

**Legacy code.** The Python prototype (`app/`, `Dockerfile`, `Makefile`) is
removed; git history keeps it.

## Consequences

- Upgrading Gleam, OTP or Typst means updating the version and checksum in
  both `flake.nix`/`flake.lock` and the `Containerfile`.
- A new runtime dependency without license information breaks the image
  build until it is resolved.

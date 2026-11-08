# 0014. Upgrade to Erlang/OTP 29

- Status: Accepted
- Date: 2026-11-07

## Context

ADR 0013 based the image on `erlang:27.3.4.19-alpine`, matching the dev
shell. That official image index lists no `linux/amd64` entry (upstream
Alpine builds for amd64 stopped after 27.3.4.13), so BuildKit silently used
the `linux/386` image for amd64. The published `0.1.0` amd64 image therefore
runs a 32-bit Erlang VM. CI only surfaced this as a warning.

## Options

1. **hexpm/erlang 27.3.4.19 Alpine** — exact current version, third-party
   images maintained by the Hex team.
2. **Official Debian slim 27.3.4.19** — official, larger image.
3. **Upgrade to OTP 29.1.2** — the current release; official Alpine images
   exist for all platforms we publish, and nixpkgs (already locked) provides
   it as `beam29Packages`.

## Decision

Option 3. Dev shell, CI and image move to Erlang/OTP 29.1.2; the image uses
the official `erlang:29.1.2-alpine`, pinned by its multi-arch index digest.

To catch a platform fallback in the future:

- the `Containerfile` sets `# check=error=true`, so BuildKit build checks
  such as `InvalidBaseImagePlatform` fail the build;
- CI checks the architecture of the built image.

The fix is released as `v0.1.1`; `0.1.0` stays published unchanged.

## Consequences

- OTP 29 deprecates some constructs (e.g. bare `catch Expr`); the code was
  updated accordingly.
- When pinning a new base image, check that its index lists every published
  platform.

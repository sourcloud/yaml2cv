# 0026. Reference the container image in the GitHub Release

- Status: Proposed
- Date: 2026-11-08

## Context

A `v*` tag publishes the multi-arch image to `ghcr.io/sourcloud/yaml2cv`
(ADR 0013) and creates a GitHub Release with notes from git-cliff
(ADR 0023). The release does not mention the image, so readers of a release
cannot see where it is or which exact image belongs to it.

## Options

1. **Reference in the notes** — append a "Container image" section with the
   pull command and the multi-arch manifest digest; no extra storage, the
   digest pins exactly what was published.
2. **Attach OCI archives** — export the image per architecture as tarballs
   (plus checksums) and upload them as release assets; works offline via
   `podman load`, but adds roughly 100 MB per architecture per release and
   slows the release job.
3. **Both.**

## Decision

Use option 1.

- `image.yml` exposes the digest returned by the multi-arch push as a
  reusable-workflow output (`digest`).
- The release job appends a "Container image" section to the git-cliff
  notes: `podman pull ghcr.io/sourcloud/yaml2cv:X.Y.Z`, the platforms, and
  the image reference by digest. It fails if no digest was passed.

## Consequences

- Each release names the exact image it shipped; pulling by digest is
  reproducible even if a tag is moved.
- `just release-notes` shows only the git-cliff part; the image section is
  added in CI.
- No image is stored on GitHub Releases; offline use still requires
  `podman save` from the registry.
- Releases before this change can be edited by hand with `gh release edit`.

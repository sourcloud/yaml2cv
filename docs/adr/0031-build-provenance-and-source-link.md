# 0031. Build provenance and a link to the source

- Status: Accepted
- Date: 2026-11-08

## Context

Anyone can run yaml2cv, and users of a deployment cannot tell whether it
runs the published source and image or a modified one. The editor also
never points back to the project.

A running instance cannot prove its own integrity: whoever changes the
source can change any self-check to report "unmodified". A trustworthy
check must happen outside the application, against something the project
signs. What the application reports about itself only exposes honest
modifications, such as an image built from uncommitted changes.

## Options

Tamper-evident check:

1. **GitHub artifact attestations** — the release workflow signs SLSA build
   provenance for the image digest through Sigstore; `gh attestation verify`
   checks that an image was built by this repository's workflow from a
   given commit. No keys to manage; free for public repositories.
2. **cosign keyless signing** — same trust model, extra tooling.
3. **None** — rely on self-reporting only.

Self-reporting and the link: footer with build information; header icon
only; both. Revision public or only on the admin listener (ADR 0020).

## Decision

**Attestations.** The publish job attests SLSA build provenance for the
multi-arch image digest with `actions/attest` and pushes the attestation to
`ghcr.io/sourcloud/yaml2cv`. No storage record is created: those require an
organisation-owned repository. Release notes show how to verify:

```sh
gh attestation verify oci://ghcr.io/sourcloud/yaml2cv@sha256:… \
  --repo sourcloud/yaml2cv
```

The operator verifies the digest of the image they run; the provenance names
the commit it was built from.

**Revision.** `GIT_REVISION` holds the full commit hash. Image builds from a
working tree with uncommitted or untracked changes append `-dirty`
(`just image` does this; CI always builds a clean checkout). The application
reads it as one of:

- *clean* — a commit hash;
- *modified* — a commit hash with the `-dirty` suffix;
- *unknown* — unset or empty, e.g. `gleam run` or a manual image build.

The admin document (ADR 0020) keeps reporting the raw value.

**Footer.** Every page gets a footer: `yaml2cv <version> · <short revision>
· Source code on GitHub`. The short revision (7 characters) links to the
commit on GitHub; a modified build adds "modified", an unknown revision
reads "revision unknown". The source link points to
`https://github.com/sourcloud/yaml2cv`. Texts are localised (ADR 0025).

The revision is public: the source is public, and the version already
appears in PDF metadata (ADR 0018).

## Consequences

- Operators can prove which commit their image came from; users of a
  deployment still have to trust the operator, since only the operator sees
  the running image digest.
- The footer is not a security control: a modified build can claim any
  revision. It helps users find the source and spots honest forks.
- The release and image workflows need `id-token: write` and
  `attestations: write`.
- Images from earlier releases carry no attestation.

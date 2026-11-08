# 0023. Generate GitHub releases from Conventional Commits

- Status: Accepted
- Date: 2026-11-08

## Context

Pushing a `v*` tag publishes the container image (ADR 0013), but no GitHub
Release is created and release notes are written by hand, if at all. Commits
already follow Conventional Commits, so the notes can be derived from them.

## Options

1. **git-cliff** — renders notes from commits between two tags using a
   `cliff.toml`; available in nixpkgs, so it runs locally and in CI; keeps the
   current flow (bump `gleam.toml`, commit `chore(release): X.Y.Z`, tag).
2. **release-please** — bot-maintained release PR that bumps the version and
   creates the tag on merge; changes the release flow.
3. **GitHub generated notes** — based on pull requests and labels, which this
   repository does not use (work lands on `master`).

## Decision

Use **git-cliff** (option 1), added to the dev shell.

- `cliff.toml` groups `feat`, `fix`, `perf`, `refactor`, `docs` and `build`
  commits; `test`, `ci`, `chore` and the `chore(release)` commit are left
  out. Breaking changes are flagged.
- `.github/workflows/release.yml` is the only workflow triggered by `v*`
  tags. It runs stages in order, each only if the previous succeeded:
  1. the tag must equal `v` + the `version` in `gleam.toml`, and CI
     (`ci.yml`, called as a reusable workflow) must pass;
  2. the image is built, smoke-tested and published (`image.yml`, called
     as a reusable workflow; it no longer triggers on tags itself);
  3. git-cliff generates the notes for the latest tag and `gh` creates the
     GitHub Release, authenticated by `GITHUB_TOKEN`.
- No `CHANGELOG.md` is kept; the GitHub Releases are the changelog.
- `just release-notes` previews the notes locally.

## Consequences

- Commit subjects become user-facing text; write them for readers.
- A GitHub Release exists only if CI passed and the image was published.
  A failed run leaves no release; fix, then delete and re-push the tag, or
  re-run the failed jobs.
- A version mismatch stops the run before any image is published.
- This refines how ADR 0013's tag publishing is triggered; what is published
  is unchanged.
- Releases for tags before v0.4.0 can be backfilled by hand with
  `git-cliff --tag-pattern`/`gh release create` if wanted.

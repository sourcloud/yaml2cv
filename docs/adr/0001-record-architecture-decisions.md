# 0001. Record architecture decisions

- Status: Accepted
- Date: 2026-11-07

## Context

The project is being rewritten iteratively, in a question–answer loop between
the owner and an AI coding agent. Decisions made in conversation are easily
lost, and both humans and agents need a durable reference for why the code is
shaped the way it is.

## Decision

Record every structural decision as a lightweight ADR (a trimmed-down
[MADR](https://adr.github.io/madr/)) in `docs/adr/`, numbered sequentially.
ADRs start as `Proposed` and become `Accepted` once the owner confirms.
Accepted ADRs are not rewritten; a changed decision gets a new ADR that
supersedes the old one.

## Consequences

- Design questions have a natural home and can be revisited explicitly.
- Small overhead per decision; keep ADRs short.

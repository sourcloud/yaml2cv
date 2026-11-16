# 0047. Document the architecture with arc42 and C4

- Status: Accepted
- Date: 2026-11-15

## Context

Design decisions are recorded as ADRs (ADR 0001), 46 of them so far. Each
explains one decision at the time it was made; many amend or supersede
earlier ones. Nothing describes the system as it is today: a newcomer has to
read the ADRs in order and replay the amendments to learn what the parts
are, how a request flows through them and how the service is deployed. The
README covers usage and operation, not structure.

The owner wants technical documentation in the spirit of the Corona-Warn-App
solution architecture: one readable document with diagrams, describing the
current system rather than its history.

## Options

Structure:

1. **arc42 with C4 diagrams** — arc42's twelve chapters give every topic a
   fixed place (goals, constraints, context, building blocks, runtime,
   deployment, crosscutting concepts, decisions, quality, risks, glossary);
   C4 levels 1 to 3 provide the structural diagrams. The decisions chapter
   links the ADRs instead of repeating them.
2. **C4 only** — context, container and component views with short prose;
   no place for runtime flows, crosscutting concepts or risks.
3. **Free form** — like the Corona-Warn-App document, but without a
   template every topic needs its own structure.

Diagrams:

1. **Mermaid in Markdown** — text next to the prose, rendered by GitHub,
   reviewed in diffs, no tool or generated file to keep in sync.
2. **C4-PlantUML with committed SVGs** — better layout, but a new tool in
   the dev shell and a render step whose output can drift from its source.
3. **Structurizr DSL** — one model with many views; the heaviest tooling.

Layout: one file, or one file per chapter.

## Decision

arc42 with C4 diagrams in Mermaid, in a single file
`docs/architecture.md`.

- The document describes the current state. History and reasoning stay in
  the ADRs; the document links them where a decision shapes a part.
- C4 levels are drawn as Mermaid flowcharts following C4 notation (person,
  software system, container, component, each labelled with its technology).
  Mermaid's own C4 diagram types are experimental and lay out poorly;
  flowcharts render reliably on GitHub. Runtime scenarios use sequence
  diagrams, the supervision tree a flowchart.
- Level 4 (code) is left out: the Gleam modules and their `///` comments are
  that level.
- The README and CONTRIBUTING link the document; AGENTS.md asks for it to
  be updated together with any change to structure, interfaces or
  deployment.

## Consequences

- One place to start for newcomers, readable on GitHub without tooling.
- The document can drift from the code. Updating it is part of every
  structural change, the same way a new ADR is.
- Diagrams are only checked by GitHub's renderer, not by CI.
- Mermaid's automatic layout limits how dense a diagram can be; large views
  are split rather than tuned by hand.

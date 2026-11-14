# 0040. Render the preview 300 ms after typing stops

- Status: Accepted, validation delay superseded by 0041
- Date: 2026-11-13

## Context

ADR 0011 renders the preview 1 s after the last input. Since ADR 0039 a
preview render takes about 20–50 ms on the server, with or without a photo,
so the wait itself has become most of the delay between an edit and the
updated preview. In visual mode the 300 ms block debounce and a round trip
come on top.

## Options

1. **300 ms** — the preview shows about 0.35 s after typing stops; renders
   during short pauses are few, and a newer request replaces one in flight
   (`hx-sync="this:replace"`).
2. **500 ms** — fewer renders on a slow or shared server, still about twice
   as fast as now.
3. **150 ms** — feels almost live, but renders between words, several times
   more Typst runs per user.

## Decision

Option 1. The preview request is triggered 300 ms after the last input
instead of 1 s. This supersedes the preview debounce of ADR 0011; validation
stays at 400 ms.

## Consequences

- The preview follows edits noticeably faster.
- More renders per user while typing; the concurrency limiter (ADR 0009)
  still bounds the load, and an overloaded server keeps the last preview.

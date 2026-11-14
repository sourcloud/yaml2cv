# 0041. One request for the validation status and the preview

- Status: Accepted
- Date: 2026-11-13

## Context

Each pause in typing sends two requests with the same YAML:
`POST /editor/validate` after 400 ms for the status line and
`POST /editor/preview` after 300 ms for the pages (ADR 0011, 0040). Both
parse the document; only the preview renders it. Rendering now takes about
20–50 ms (ADR 0039), so waiting for it no longer holds the status back
noticeably.

## Options

1. **One request** — `POST /editor/preview` answers with the status, and for
   a valid document also the pages, swapped out of band into `#preview`.
   Half the requests and parses; the status appears with the preview.
2. **Keep two requests** — the status can come before the render, at the
   cost of sending and parsing the document twice.

## Decision

Option 1.

- The status element `#validation` posts the YAML to `/editor/preview`
  300 ms after the last input and shows the preview indicator while the
  request runs.
- The response body is the status alert, swapped into `#validation`. For a
  valid document it is followed by `<div id="preview"
  hx-swap-oob="innerHTML">` holding the page stack, or the alert explaining
  why the preview is unavailable.
- An invalid document gets only the error list, so the last good preview
  stays, as before (`204` is no longer used).
- `POST /editor/validate` is removed. Editor routes are outside the
  stability promise (ADR 0033).

This supersedes the separate validate request of ADR 0011 and the 400 ms
validation delay kept by ADR 0040.

## Consequences

- One request per pause in typing instead of two.
- The status shows 300 ms after typing stops instead of 400 ms, but now
  waits for the render; when the server is busy it still reports the
  document as valid and the preview explains the delay.

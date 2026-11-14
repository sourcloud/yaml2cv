# 0019. SVG page previews and gzip responses

- Status: Accepted, page embedding amended by 0039
- Date: 2026-11-07

## Context

The editor preview (ADR 0011) shows PNG pages rendered at 110 ppi. They look
blurry on high-density displays and when zoomed. Typst can render each page
as SVG instead; text then becomes vector outlines that stay sharp at any
scale.

SVG pages are larger than the PNGs (about 230 KB against 125 KB for the
example page, before base64) but compress well (about 50 KB with gzip).
Typst keeps links in the SVG as `<a href>` elements, and link targets come
from the CV, i.e. from the user.

## Options

Embedding:

1. **`<img>` with a `data:` URI** — the browser treats the SVG as an image:
   no scripts run, links are inert, nothing is fetched. CSP unchanged.
2. **Inline `<svg>`** — smaller and links clickable, but user-supplied URLs
   (e.g. `javascript:`) would become live links inside the editor page.

PNG: replace it, or keep it next to SVG for later use.

Size: compress responses in the application, or leave it to a proxy.

## Decision

- The renderer's preview function returns SVG pages (`render_svg_pages`),
  still limited to the first 10 pages. PNG rendering is removed.
- The editor embeds each page as `<img src="data:image/svg+xml;base64,…">`.
- A middleware gzips response bodies held in memory when the client accepts
  gzip, the content type is textual (`text/*`, JSON, problem JSON, SVG) and
  the body is at least 1 KiB. It sets `content-encoding: gzip` and
  `vary: accept-encoding`. Static files and PDFs are sent unchanged.
- Responses carry no secrets (no sessions, cookies or tokens), so mixing user
  input and compression (BREACH) exposes nothing.

This supersedes the PNG preview part of ADR 0011.

## Consequences

- Previews stay sharp on every display; preview responses get smaller on the
  wire than the PNG ones were.
- Links in the preview are not clickable.
- Compression costs some CPU per response; a proxy in front no longer needs
  to compress these responses.

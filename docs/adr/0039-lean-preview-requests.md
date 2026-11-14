# 0039. Keep the photo in the browser for previews and send SVG as text

- Status: Accepted, extended to all editor requests by 0042
- Date: 2026-11-13

## Context

With a profile photo (ADR 0028, 0030) the editor feels sluggish. Measured on
a local server with the example CV and a 900 × 1157 photo of 141 KB:

| per pause in typing                | without photo | with photo |
| ---------------------------------- | ------------- | ---------- |
| upload, validate and preview, each | 1.8 KB        | 208 KB     |
| preview download (gzip)            | 67 KB         | 250 KB     |
| preview render time                | 19 ms         | 48 ms      |

The photo travels three times per pause: up with the validate request, up
with the preview request and down again inside the SVG page, where Typst
embeds the image bytes unchanged. The preview page is then base64-encoded a
second time for its `data:` URI (ADR 0019), which gzip can hardly compress.

The service stays stateless (ADR 0010): it cannot remember the photo between
requests. Making the photo smaller is not an option either; ADR 0030 raised
its size on purpose.

## Options

1. **Keep the photo in the browser for previews** — before a validate or
   preview request the editor replaces the photo in the YAML with a small,
   single-coloured PNG of the same pixel size; when the preview arrives it
   puts the real photo back in place of the placeholder. Since Typst embeds
   images verbatim and lays them out by their aspect ratio, the page looks
   the same. No API change; more editor script.
2. **Send SVG pages as text** — embed each page as a percent-encoded
   `data:image/svg+xml,` URI instead of base64, so gzip compresses the
   markup. Server-only, helps every preview.
3. **Gzip request bodies in the browser** — base64 JPEG shrinks by only
   about a quarter; little gain for the extra decoding on the server.
4. **Smaller photo** — rejected by ADR 0030.

## Decision

Options 1 and 2.

**SVG as text.** The page stack embeds each page as
`data:image/svg+xml,` followed by the SVG percent-encoded with Erlang's
`uri_string:quote/2`, keeping `/:;,=()!*'~?@$+` unencoded so an embedded
base64 image stays readable as is. A page that is not valid UTF-8 falls back
to base64. Pages remain `<img>` sources, so ADR 0019's security properties
hold.

**Photo kept in the browser.** For `/editor/validate` and `/editor/preview`
the editor script looks for a `data:image/jpeg;base64,` or
`data:image/png;base64,` URI in the YAML. It substitutes the placeholder only
when it can tell that the server would accept the photo: the base64 has no
whitespace and decodes, the image is at most 512 KiB, the signature matches
the declared type, the image is complete, its sides are between 1 and 4000
pixels, and it carries no EXIF data (whose orientation might change the
layout). Otherwise it sends the photo as is, so the server still reports
every photo error. Placeholders are cached per photo. Before the preview is
swapped in, the placeholder URI in the response is replaced by the real one.

Downloading the PDF and the API always send and use the real photo.

## Consequences

- With a photo, each pause in typing uploads about 2 KB per request instead
  of about 200 KB, and the preview download shrinks from about 250 KB to
  about 50 KB. Without a photo the preview is about 30 % smaller.
- The server renders a tiny placeholder, so preview compile time no longer
  depends on the photo.
- The editor script mirrors part of the server's photo validation; when the
  two disagree, the script falls back to sending the photo, which is only
  slower, never wrong.
- If the script fails to put the photo back, the preview shows a grey box
  where the photo belongs; the PDF is unaffected.

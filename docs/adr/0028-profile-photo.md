# 0028. Profile photo inside the CV document

- Status: Accepted, photo size amended by 0030
- Date: 2026-11-08

## Context

A profile photo is still common on CVs in Germany. yaml2cv is stateless and
must not store any data a user provides (ADR 0010): there is no session, no
upload store and no cache. The editor re-renders the preview whenever typing
pauses (ADR 0011, ADR 0019), so whatever carries the photo has to travel with
every request. Typst reads images from files below `--root` only; it cannot
decode base64 itself.

## Options

Transport:

1. **Base64 data URI inside the YAML** (`person.photo`) — the CV stays one
   self-contained file the user keeps; the API is unchanged. The YAML gets a
   long line and every request carries the photo.
2. **Separate multipart part** — the YAML stays small, but the API changes,
   the document is no longer self-contained and the photo has to be picked
   again in every session.

Preparation: shrink and re-encode in the browser, or send the file as
picked.

## Decision

Option 1, with the photo shrunk in the browser.

**Schema** (extends ADR 0007, still `schema_version: 1`):

```yaml
style:
  photo_shape: rounded     # optional, default rectangle;
                           # one of: rectangle, rounded, circle
person:
  photo: data:image/jpeg;base64,/9j/4AAQ...   # optional
```

`person.photo` must be a `data:image/jpeg;base64,` or `data:image/png;base64,`
URI. The base64 must decode, the bytes must start with the JPEG or PNG
signature of the declared type, be at most 512 KiB and the image at most
4000 × 4000 pixels (read from the PNG `IHDR` or JPEG `SOF` header) so that a
small file cannot expand into a huge bitmap. SVG, URLs and file paths are
rejected, so a CV can never make Typst read anything but its own photo.
Error messages never repeat the photo content.

**Rendering.** The JSON handed to the theme holds the file name
(`photo.jpg` or `photo.png`) instead of the bytes; the renderer writes the
decoded photo under that name into the per-render job directory next to
`cv.json` (ADR 0009). The job directory is private to the service user and
always removed, so the photo is not kept beyond the render. Both themes
place the photo on the right of the header, 3.5 × 4.5 cm, cropped to fill;
`circle` uses a 3.5 cm square with fully rounded corners. Without a photo the
header is unchanged.

**Editor.** A "Choose photo" control decodes the picked JPEG or PNG in the
browser, crops it to the 3.5 : 4.5 aspect ratio, scales it to at most
600 × 771 pixels and re-encodes it as JPEG. Re-encoding through a canvas
drops EXIF metadata such as GPS location and camera details. The picked file
leaves the browser only inside the CV. The visual editor shows a thumbnail
instead of the base64 text.

**Body limit.** `MAX_BODY_BYTES` defaults to 1 048 576 (was 262 144) so a
document can hold a photo at the 512 KiB limit (≈ 700 KiB as base64).

## Consequences

- Statelessness is preserved; the photo lives only in the request, in memory
  and in the job directory for the duration of one render, and is never
  logged.
- Every preview request carries the photo again, typically 50–80 KiB after
  shrinking in the browser.
- API clients that send photos themselves are not re-encoded by the server;
  EXIF data they send ends up in the PDF they get back. No image library is
  added to the service.
- The YAML source holds one long line; it stays copyable and self-contained.

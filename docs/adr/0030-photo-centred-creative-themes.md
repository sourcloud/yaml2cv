# 0030. Photo-centred themes for creative jobs

- Status: Accepted, timespans, skills and the studio sidebar amended by 0037
- Date: 2026-11-08

## Context

`classic` and `minimal` (ADR 0009, ADR 0015) are quiet, text-first layouts
that place the optional photo (ADR 0028) as a small box beside the header.
Applicants for design and other creative jobs want a CV that looks designed
and is built around their portrait. A designed look needs a sans-serif
typeface, but Typst embeds only serif and monospace fonts and ADR 0009 ships
no font files. The photo is cropped in the browser to 3.5 : 4.5 and scaled to
at most 600 × 771 pixels, which prints sharply only up to about 7 cm wide.

Three layouts were drafted and compared: a sidebar portrait, a hero band
across the top and a magazine-style cover page. All three were kept.

## Options

Fonts:

1. **Commit static font files** under `priv/fonts/` and pass them to Typst
   with `--font-path`; shared by all themes.
2. **Fetch fonts at build time** in Nix and the Containerfile with checksums,
   like Typst itself (ADR 0013); nothing binary in git, but one more version
   to keep in sync in three places.
3. **Embedded fonts only** — no sans-serif for display type.

Large photo on the cover page:

1. **Keep the 3.5 : 4.5 ratio and raise the browser size** so the photo is
   never cut at the sides and prints at about 200 dpi.
2. **Fill a half-page strip** — dramatic, but crops faces and prints soft.

## Decision

**Three new themes.** `style.theme` (ADR 0007) additionally accepts
`studio`, `spotlight` and `cover`; `classic` stays the default. All three use
the accent colour (`style.color`) prominently, set text in Inter and display
type in Inter Display, honour `style.paper` and `style.photo_shape`, and keep
the spacing unit of ADR 0017.

- **`studio`** — a light accent-tinted column runs down the left of every
  page. The photo fills its top-left corner, bleeding off the page; contact
  details and skills sections sit below it. Name, title and all other
  sections take the right column.
- **`spotlight`** — page one opens with a full-width accent band; the photo
  fills its left end, the name, title and contact details are set in white
  beside it. Below, a single column; skills sections sit side by side.
- **`cover`** — page one is a cover: the photo bleeds into the top-left
  corner at about 10.5 × 13.5 cm with the name on an accent block below it;
  the first text section and the contact details fill the right half. The
  remaining sections start on page two under a running header.

With `rectangle` the photo bleeds to the page edge; `rounded` and `circle`
inset it with rounded corners. Without a photo every theme shows the same
box filled with the accent colour and the person's initials (first letters
of the first and last word of `person.name`), so the layout keeps its anchor.

**Fonts.** Option 1. The static TTFs of Inter 4.1 (SIL Open Font License
1.1) that the themes use — Inter Regular, Medium, SemiBold and Bold, Inter
Display Bold and Black — are committed to `priv/fonts/inter/` with the
license. The renderer passes `--font-path <priv>/fonts` next to
`--ignore-system-fonts`, so output stays identical on every machine. This
amends ADR 0009, which shipped no font files.

**Photo size.** Option 1. The editor scales the cropped photo to at most
900 × 1157 pixels (was 600 × 771, ADR 0028). The server limits of ADR 0028
are unchanged.

## Consequences

- The repository and the image grow by about 2.4 MB of font files; updating
  Inter means replacing the files and the license together.
- Every theme can use Inter, but `classic` and `minimal` stay unchanged.
- Photos picked in the editor are about twice as large (typically
  120–180 KiB), and so is every preview request carrying one.
- `cover` always produces at least two pages.
- The sidebar of `studio` holds a fixed amount of content; a very long list
  of contact links or skills runs past the bottom of page one.

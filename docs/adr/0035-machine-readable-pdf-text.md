# 0035. Machine-readable PDF text

- Status: Accepted
- Date: 2026-11-08

## Context

CVs are handed in to application processes where software reads them
first: applicant tracking systems and AI screening extract the PDF text
and look for sections, job titles and links. An inspection of the five
themes with pdfminer showed that the PDFs are tagged, carry Unicode maps
for every font and contain working links, but:

- section titles are drawn by a custom block, not as Typst headings, so
  the structure tree has no heading tags and the PDF has no bookmarks;
- studio, spotlight and cover space uppercase section titles with
  `tracking: 0.14em`, which extractors read as separate letters
  (`P R O F E S S I O N A L`): the gap is wider than the 0.1 em that
  pdftotext and pdfminer treat as a word break;
- classic and minimal print a contact link only as its label (`GitHub`),
  so the URL is missing from the extracted text.

The reading order of multi-column themes is a separate, larger problem and
is not addressed here.

## Options

Headings:

1. **Name as level 1, sections as level 2**, with bookmarks.
2. The same without bookmarks.
3. Sections only, as level 1.

Letter spacing of section titles: **reduce to 0.05 em**, or remove it.

Link text in classic and minimal: **label and address**
(`GitHub: github.com/johndoe`), the address only, or label and full URL.

Testing: **pdftotext from poppler in the dev shell**, or only search the raw
PDF bytes and query the Typst document, which cannot check extracted text.

## Decision

- Every theme renders the person's name as a level 1 heading and each
  section title as a level 2 heading, styled with show rules so the look
  stays the same. Typst tags them `H1` and `H2`, and the section headings
  appear as PDF bookmarks.
- Section titles that use letter spacing use at most 0.05 em.
- classic and minimal print contact links as `label: address` and the
  website as its address, where the address is the URL without `http://`
  or `https://`, as studio, spotlight and cover already show it. The link
  target stays the full URL.
- `poppler-utils` joins the dev shell (and so CI), not the container image.
  Tests render each theme and check the text pdftotext extracts.

## Consequences

- The PDF output changes visibly only in letter spacing and link text,
  which ADR 0033 allows in a minor release.
- New themes must use `heading` for the name and section titles, keep
  letter spacing at or below 0.05 em, and print link addresses; the tests
  cover every theme in `cv.themes`.
- The extraction tests depend on pdftotext's heuristics. Other extractors
  may still differ, so the tests check what matters (words, headings,
  addresses), not exact layout.
- Reading order in the multi-column themes, the document language and the
  PDF metadata remain open.

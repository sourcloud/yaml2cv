// yaml2cv "cover" theme: a cover page led by a large portrait, the CV itself
// from page two (ADR 0030).
//
// All CV content comes from cv.json as data; nothing in it is evaluated as
// Typst markup. The only word the theme adds is the "Website" label, which
// reads the same in English and German.

#let cv = json("cv.json")

#let accents = (
  // A single-ink black, so small text stays crisp in print (ADR 0017).
  black: luma(0%),
  blue: rgb(22%, 45%, 70%),
  burgundy: rgb(60%, 0%, 0%),
  green: rgb(35%, 70%, 30%),
  grey: rgb(55%, 55%, 55%),
  orange: rgb(95%, 55%, 15%),
  purple: rgb(50%, 33%, 80%),
  red: rgb(95%, 20%, 20%),
)
#let papers = (a4: "a4", letter: "us-letter")
#let accent = accents.at(cv.style.color)
#let ink = luma(12%)
#let muted = luma(38%)
// The paragraph leading; all vertical gaps are multiples of it (ADR 0017).
#let unit = 0.6em
#let cover-pad = 1.4cm

// The generator text is set by the service, not the CV (ADR 0018).
#set document(
  title: cv.person.name,
  author: cv.person.name,
  description: sys.inputs.at("generator", default: none),
  keywords: ("yaml2cv",),
)
#set page(paper: papers.at(cv.style.paper), margin: 0pt)
#set text(font: "Inter", size: 9.5pt, fill: ink, lang: "en")
#set par(justify: false, leading: unit)
// The name and section titles are headings, so the PDF tags them H1 and H2
// and lists the sections as bookmarks (ADR 0035). Themes style them.
#show heading: it => text(weight: "regular", it.body)
#set list(
  indent: 0pt,
  body-indent: 0.6em,
  spacing: unit,
  marker: text(fill: accent)[•],
)

// Shared pieces ---------------------------------------------------------------

#let label(body) = text(
  size: 7.5pt,
  weight: "semibold",
  // Wider spacing makes text extraction split the words (ADR 0035).
  tracking: 0.05em,
  fill: accent,
  upper(body),
)

#let initials = {
  let words = cv.person.name.split(" ").filter(w => w.len() > 0)
  let picks = if words.len() > 1 { (words.first(), words.last()) } else {
    words
  }
  picks.map(w => upper(w.clusters().first())).join(default: "")
}

// The photo cropped to fill a box (ADR 0028), or the initials when there is
// no photo.
#let portrait(width, height, radius: 0pt) = box(
  width: width,
  height: height,
  radius: radius,
  clip: true,
  fill: accent.darken(25%),
  if cv.person.photo != none {
    image(cv.person.photo, width: 100%, height: 100%, fit: "cover")
  } else {
    align(center + horizon, text(
      font: "Inter Display",
      weight: "bold",
      size: calc.min(width, height) * 0.38,
      fill: white,
      initials,
    ))
  },
)

// Strips the scheme so web addresses read as they are typed.
#let address(url) = url.replace(regex("^https?://"), "")

// A web address with a small label above it.
#let labelled-link(label, url) = stack(
  spacing: 0.45em,
  text(size: 7pt, fill: muted, label),
  link(url, address(url)),
)

// Short items first, the postal address next to them, then the web
// addresses, each with its label.
#let contact-items = {
  let c = cv.contact
  let items = ()
  if c.phone != none { items.push(c.phone) }
  if c.email != none { items.push(link("mailto:" + c.email, c.email)) }
  if cv.person.address != none { items.push(cv.person.address) }
  if c.website != none { items.push(labelled-link("Website", c.website)) }
  for l in c.links { items.push(labelled-link(l.label, l.url)) }
  items
}

// The first text section introduces the person on the cover.
#let intro-index = cv.sections.position(s => s.kind == "text")
#let intro = if intro-index != none { cv.sections.at(intro-index) }

// Cover -----------------------------------------------------------------------

#context {
  let half = page.width / 2
  let shape = cv.style.photo_shape
  // The photo keeps the 3.5 : 4.5 ratio the editor crops to (ADR 0028).
  let photo = if shape == "rectangle" {
    // Bleeds into the top-left corner of the page.
    portrait(half, half / 3.5 * 4.5)
  } else {
    let size = half - 2 * cover-pad
    pad(x: cover-pad, top: cover-pad, portrait(
      size,
      if shape == "circle" { size } else { size / 3.5 * 4.5 },
      radius: if shape == "circle" { size / 2 } else { 0.5cm },
    ))
  }
  grid(
    columns: (half, half),
    rows: page.height,
    block(width: 100%, height: 100%, fill: accent, {
      photo
      place(bottom + left, pad(cover-pad, {
        set text(fill: white)
        stack(
          spacing: 1.4em,
          heading(level: 1, text(
            font: "Inter Display",
            size: 36pt,
            weight: "black",
            tracking: -0.01em,
            {
              set par(leading: 0.2em)
              cv.person.name
            },
          )),
          ..if cv.person.title != none {
            (text(size: 12pt, weight: "medium", cv.person.title),)
          },
        )
      }))
    }),
    pad(x: cover-pad, top: 2.4cm, bottom: cover-pad, block(height: 100%, {
      if intro != none {
        heading(level: 2, label(intro.name))
        v(1.5 * unit)
        text(size: 12pt, par(leading: 0.7em, intro.text))
      }
      // Contact details sit at the foot of the page, below any long intro.
      v(1fr)
      if contact-items.len() > 0 {
        line(length: 1.2cm, stroke: 1.5pt + accent)
        v(1.5 * unit)
        stack(spacing: 1.6 * unit, ..contact-items)
      }
    })),
  )
}

// CV pages --------------------------------------------------------------------

#set page(
  margin: (x: 2cm, top: 2.6cm, bottom: 2.5cm),
  header: context {
    set text(size: 7.5pt, fill: muted)
    grid(
      columns: (1fr, auto),
      text(weight: "semibold", fill: ink, cv.person.name),
      counter(page).display(),
    )
  },
)

#let section-heading(name) = block(
  above: 3 * unit,
  below: 1.8 * unit,
  sticky: true,
  grid(
    columns: (auto, 1fr),
    column-gutter: 0.8em,
    align: horizon,
    heading(level: 2, label(name)),
    line(length: 100%, stroke: 0.5pt + accent.lighten(50%)),
  ),
)

// Entries: the timespan in a narrow left column, the rest beside it.
#let entry(e) = block(below: 2.5 * unit, breakable: false, grid(
  columns: (3.2cm, 1fr),
  column-gutter: 0.6cm,
  text(size: 8.5pt, weight: "medium", fill: accent, e.timespan),
  stack(
    spacing: unit,
    text(size: 10.5pt, weight: "semibold", e.title),
    ..{
      let details = (e.organization, e.location).filter(x => x != none)
      if details.len() > 0 { (text(fill: muted, details.join("  ·  ")),) }
    },
    ..if e.bullets.len() > 0 { (list(..e.bullets),) },
  ),
))

// Skills in two columns of name and level pairs.
#let skills(items) = block(below: 2 * unit, grid(
  columns: (1fr, auto, 1fr, auto),
  column-gutter: (1em, 1.2cm, 1em),
  row-gutter: unit,
  ..items
    .map(s => (
      s.name,
      if s.level != none { text(size: 0.9em, fill: muted, s.level) },
    ))
    .flatten(),
))

#for (i, section) in cv.sections.enumerate() {
  if i == intro-index { continue }
  section-heading(section.name)
  if section.kind == "entries" {
    for e in section.entries { entry(e) }
  } else if section.kind == "skills" {
    skills(section.items)
  } else if section.kind == "text" {
    block(below: 2 * unit, par(section.text))
  }
}

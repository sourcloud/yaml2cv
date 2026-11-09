// yaml2cv "spotlight" theme: an accent band across the top of page one with
// the portrait at its left end (ADR 0030).
//
// All CV content comes from cv.json as data; nothing in it is evaluated as
// Typst markup. The theme adds no words of its own, so a CV reads the same
// in any language.

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

// Page geometry: the photo keeps the 3.5 : 4.5 ratio the editor crops to
// (ADR 0028) and sets the minimum height of the band.
#let margin = 2cm
#let photo-width = 7cm
#let photo-height = photo-width / 3.5 * 4.5
#let band-pad = 1.2cm

// The generator text is set by the service, not the CV (ADR 0018).
#set document(
  title: cv.person.name,
  author: cv.person.name,
  description: sys.inputs.at("generator", default: none),
  keywords: ("yaml2cv",),
)
#set page(
  paper: papers.at(cv.style.paper),
  margin: (x: margin, top: margin, bottom: margin + 0.5cm),
)
#set text(font: "Inter", size: 9.5pt, fill: ink, lang: "en")
#set par(justify: false, leading: unit)
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
  tracking: 0.14em,
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

#let contact-items = {
  let c = cv.contact
  let items = ()
  if c.email != none { items.push(link("mailto:" + c.email, c.email)) }
  if c.phone != none { items.push(c.phone) }
  if c.website != none { items.push(link(c.website, address(c.website))) }
  for l in c.links {
    items.push(stack(
      spacing: 0.45em,
      text(size: 6.5pt, fill: white.transparentize(30%), upper(l.label)),
      link(l.url, address(l.url)),
    ))
  }
  if cv.person.address != none { items.push(cv.person.address) }
  items
}

// Header band (page one) --------------------------------------------------------

#let header-text = {
  set text(fill: white)
  stack(
    spacing: 1.6em,
    text(
      font: "Inter Display",
      size: 34pt,
      weight: "black",
      tracking: -0.01em,
      {
        set par(leading: 0.2em)
        cv.person.name
      },
    ),
    ..if cv.person.title != none {
      (text(size: 12pt, weight: "medium", cv.person.title),)
    },
    ..if contact-items.len() > 0 {
      (
        {
          set text(size: 8pt)
          block(above: 0pt, grid(
            columns: (1fr, 1fr),
            column-gutter: 1em,
            row-gutter: 1em,
            // Values line up when only some carry a label above them.
            align: bottom,
            ..contact-items,
          ))
        },
      )
    },
  )
}

#context {
  let page-width = page.width
  let text-width = page-width - photo-width - 2 * band-pad
  // The band grows when the name or the contact details need more room than
  // the photo is tall.
  let text-height = measure(header-text, width: text-width).height
  let band-height = calc.max(photo-height, text-height + 2 * band-pad)
  let shape = cv.style.photo_shape
  place(top + left, dx: -margin, dy: -margin, block(
    width: page-width,
    height: band-height,
    fill: accent,
    grid(
      columns: (photo-width, 1fr),
      if shape == "rectangle" {
        // Bleeds into the top-left corner of the page.
        portrait(photo-width, band-height)
      } else {
        let size = photo-width - 2 * band-pad
        block(height: band-height, align(center + horizon, portrait(
          size,
          if shape == "circle" { size } else { size / 3.5 * 4.5 },
          radius: if shape == "circle" { size / 2 } else { 0.4cm },
        )))
      },
      block(
        height: band-height,
        inset: band-pad,
        align(bottom, header-text),
      ),
    ),
  ))
  v(band-height - margin + 3 * unit)
}

// Sections --------------------------------------------------------------------

#let section-heading(name) = block(
  above: 3 * unit,
  below: 1.8 * unit,
  sticky: true,
  grid(
    columns: (auto, 1fr),
    column-gutter: 0.8em,
    align: horizon,
    label(name), line(length: 100%, stroke: 0.5pt + accent.lighten(50%)),
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

#let skills(items) = grid(
  columns: (1fr, auto),
  column-gutter: 1em,
  row-gutter: unit,
  ..items
    .map(s => (
      s.name,
      if s.level != none { text(size: 0.9em, fill: muted, s.level) },
    ))
    .flatten(),
)

#for section in cv.sections.filter(s => s.kind != "skills") {
  section-heading(section.name)
  if section.kind == "entries" {
    for e in section.entries { entry(e) }
  } else if section.kind == "text" {
    block(below: 2 * unit, par(section.text))
  }
}

// Skills sections sit side by side, up to three in a row.
#let skill-sections = cv.sections.filter(s => s.kind == "skills")
#if skill-sections.len() > 0 {
  grid(
    columns: (1fr,) * calc.min(skill-sections.len(), 3),
    column-gutter: 1.2cm,
    ..skill-sections.map(s => {
      section-heading(s.name)
      skills(s.items)
    }),
  )
}

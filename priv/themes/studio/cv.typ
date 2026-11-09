// yaml2cv "studio" theme: a tinted sidebar led by a large portrait
// (ADR 0030).
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
#let tint = accent.lighten(88%)
#let ink = luma(12%)
#let muted = luma(38%)
// The paragraph leading; all vertical gaps are multiples of it (ADR 0017).
#let unit = 0.6em

// Page geometry: the sidebar is as wide as the photo; the photo keeps the
// 3.5 : 4.5 ratio the editor crops to (ADR 0028).
#let side = 6.6cm
#let gutter = 1.2cm
#let top-margin = 2cm
#let side-pad = 0.9cm

// The generator text is set by the service, not the CV (ADR 0018).
#set document(
  title: cv.person.name,
  author: cv.person.name,
  description: sys.inputs.at("generator", default: none),
  keywords: ("yaml2cv",),
)
#set page(
  paper: papers.at(cv.style.paper),
  margin: (left: side + gutter, right: 1.8cm, top: top-margin, bottom: 2.5cm),
  background: place(top + left, rect(width: side, height: 100%, fill: tint)),
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

// The photo cropped to fill a box (ADR 0028), or the initials on the accent
// colour when there is no photo.
#let portrait(width, height, radius: 0pt) = box(
  width: width,
  height: height,
  radius: radius,
  clip: true,
  fill: accent,
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
      text(size: 7pt, fill: muted, l.label),
      link(l.url, address(l.url)),
    ))
  }
  if cv.person.address != none { items.push(cv.person.address) }
  items
}

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

// Sidebar (page one): photo, contact details, skills sections -------------------

#let sidebar = block(width: side, {
  let shape = cv.style.photo_shape
  if shape == "rectangle" {
    // Bleeds into the top-left corner of the page.
    portrait(side, side / 3.5 * 4.5)
  } else {
    let size = side - 2 * side-pad
    v(top-margin)
    align(center, portrait(
      size,
      if shape == "circle" { size } else { size / 3.5 * 4.5 },
      radius: if shape == "circle" { size / 2 } else { 0.4cm },
    ))
  }
  pad(x: side-pad, top: 3 * unit, {
    set text(size: 8.5pt)
    if contact-items.len() > 0 {
      line(length: 1.2cm, stroke: 1.5pt + accent)
      v(1.5 * unit)
      stack(spacing: 1.6 * unit, ..contact-items)
    }
    for s in cv.sections.filter(s => s.kind == "skills") {
      block(above: 3.5 * unit, below: 1.5 * unit, label(s.name))
      skills(s.items)
    }
  })
})

#place(top + left, dx: -(side + gutter), dy: -top-margin, sidebar)

// Main column -----------------------------------------------------------------

#block(below: 3.5 * unit, stack(
  spacing: 1em,
  text(
    font: "Inter Display",
    size: 32pt,
    weight: "bold",
    tracking: -0.01em,
    cv.person.name,
  ),
  ..if cv.person.title != none {
    (text(size: 13pt, weight: "medium", fill: accent, cv.person.title),)
  },
))

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

#let entry(e) = block(below: 2.5 * unit, breakable: false, stack(
  spacing: unit,
  text(size: 8pt, weight: "medium", fill: accent, e.timespan),
  text(size: 10.5pt, weight: "semibold", e.title),
  ..{
    let details = (e.organization, e.location).filter(x => x != none)
    if details.len() > 0 { (text(fill: muted, details.join("  ·  ")),) }
  },
  ..if e.bullets.len() > 0 { (list(..e.bullets),) },
))

#for section in cv.sections.filter(s => s.kind != "skills") {
  section-heading(section.name)
  if section.kind == "entries" {
    for e in section.entries { entry(e) }
  } else if section.kind == "text" {
    block(below: 2 * unit, par(section.text))
  }
}

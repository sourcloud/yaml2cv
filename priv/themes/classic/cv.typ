// yaml2cv "classic" theme, inspired by moderncv classic (ADR 0009).
//
// All CV content comes from cv.json as data; nothing in it is evaluated as
// Typst markup.

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
// Dark enough that small and italic text prints solidly on office printers.
#let muted = luma(35%)
#let date-column = 25%
// The paragraph leading; all vertical gaps are multiples of it (ADR 0017).
#let unit = 0.6em

// Metadata describes the candidate for screening software: the title as
// subject, the skills as keywords, then the generator credit set by the
// service, not the CV (ADR 0018, ADR 0036).
#let skill-names = (
  cv
    .sections
    .filter(s => s.kind == "skills")
    .map(s => s.items.map(i => i.name))
    .flatten()
    .dedup()
)
#let generator = sys.inputs.at("generator", default: none)
#set document(
  title: cv.person.name,
  author: cv.person.name,
  description: cv.person.title,
  keywords: skill-names + if generator != none { (generator,) } else { () },
)
#set page(
  paper: papers.at(cv.style.paper),
  margin: (x: 2cm, top: 2cm, bottom: 2.5cm),
)
#set text(font: "New Computer Modern", size: 11pt, lang: cv.language)
#set par(justify: false, leading: unit)
// The name and section titles are headings, so the PDF tags them H1 and H2
// and lists the sections as bookmarks (ADR 0035). Themes style them.
#show heading: it => text(weight: "regular", it.body)
#set list(
  indent: 0pt,
  body-indent: 0.5em,
  spacing: unit,
  marker: text(fill: accent)[•],
)

// Header ----------------------------------------------------------------------

// Links show their address, so it survives text extraction (ADR 0035).
#let address(url) = url.replace(regex("^https?://"), "")

#let contact-items = {
  let c = cv.contact
  let items = ()
  if cv.person.address != none { items.push(cv.person.address) }
  if c.phone != none { items.push(c.phone) }
  if c.email != none { items.push(link("mailto:" + c.email, c.email)) }
  if c.website != none { items.push(link(c.website, address(c.website))) }
  for l in c.links {
    // Kept on one line, so the label never ends a line on its own.
    items.push(box(link(l.url, l.label + ": " + address(l.url))))
  }
  items
}

// Contact items separated by dots. A line may break after a dot, never
// before one.
#let contact-line = {
  let last = contact-items.len() - 1
  for (i, item) in contact-items.enumerate() {
    if i < last { box[#item~#h(0.3em)·] + h(0.3em) + [ ] } else { item }
  }
}

// Profile photo (ADR 0028): cropped to fill a fixed box. The renderer writes
// the file next to cv.json; the JSON holds only its name.
#let photo-box(stroke: none) = {
  let shape = cv.style.photo_shape
  let height = if shape == "circle" { 3.5cm } else { 4.5cm }
  let radius = if shape == "circle" { 1.75cm } else if shape == "rounded" {
    0.3cm
  } else { 0pt }
  box(
    width: 3.5cm,
    height: height,
    radius: radius,
    clip: true,
    stroke: stroke,
    image(cv.person.photo, width: 100%, height: 100%, fit: "cover"),
  )
}

// The header text, with the photo on the right when there is one.
#let with-photo(header, stroke: none) = if cv.person.photo == none {
  header
} else {
  grid(
    columns: (1fr, auto),
    column-gutter: 1em,
    header, photo-box(stroke: stroke),
  )
}

#block(below: 3 * unit, with-photo(
  stack(
    spacing: 0.9em,
    heading(level: 1, text(size: 28pt, fill: accent, cv.person.name)),
    ..if cv.person.title != none {
      (text(size: 14pt, fill: muted, style: "italic", cv.person.title),)
    },
    ..if contact-items.len() > 0 {
      (text(size: 9.5pt, fill: muted, contact-line),)
    },
  ),
  stroke: 0.75pt + accent,
))

// Sections --------------------------------------------------------------------

#let row(side, main) = grid(
  columns: (date-column, 1fr),
  column-gutter: 1em,
  align(right, side), main,
)

#let section-heading(name) = block(
  above: 3 * unit,
  below: 1.5 * unit,
  sticky: true,
  row(
    box(width: 100%, height: 0.6em, baseline: -0.2em, fill: accent),
    heading(level: 2, text(size: 14pt, fill: accent, name)),
  ),
)

#let entry(e) = block(below: 2 * unit, breakable: false, row(
  text(fill: muted, e.timespan),
  {
    let details = (e.organization, e.location).filter(x => x != none)
    strong(e.title)
    if details.len() > 0 { [, ] + emph(details.join(", ")) }
    if e.bullets.len() > 0 {
      block(above: unit, list(..e.bullets))
    }
  },
))

#let skill(s) = block(below: unit, row(
  text(fill: muted, s.name),
  if s.level != none { s.level },
))

#for section in cv.sections {
  section-heading(section.name)
  if section.kind == "entries" {
    for e in section.entries { entry(e) }
  } else if section.kind == "skills" {
    for s in section.items { skill(s) }
  } else if section.kind == "text" {
    row([], section.text)
  }
}

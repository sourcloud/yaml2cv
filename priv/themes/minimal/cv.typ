// yaml2cv "minimal" theme: a reduced single-column layout (ADR 0015).
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
// Running text is kept to a comfortable line length (about 75 characters);
// timespans still sit flush with the right margin.
#let measure = 13cm
// The paragraph leading; all vertical gaps are multiples of it (ADR 0017).
#let unit = 0.6em

// The generator text is set by the service, not the CV (ADR 0018).
#set document(
  title: cv.person.name,
  author: cv.person.name,
  description: sys.inputs.at("generator", default: none),
  keywords: ("yaml2cv",),
)
#set page(
  paper: papers.at(cv.style.paper),
  margin: (x: 2.2cm, top: 2.2cm, bottom: 2.7cm),
)
#set text(font: "Libertinus Serif", size: 10.5pt, lang: "en")
#set par(justify: false, leading: unit)
// The name and section titles are headings, so the PDF tags them H1 and H2
// and lists the sections as bookmarks (ADR 0035). Themes style them.
#show heading: it => text(weight: "regular", it.body)
#set list(
  indent: 0pt,
  body-indent: 0.5em,
  spacing: unit,
  marker: text(fill: muted)[–],
)

// Header ----------------------------------------------------------------------

#let contact-items = {
  let c = cv.contact
  let items = ()
  if cv.person.address != none { items.push(cv.person.address) }
  if c.phone != none { items.push(c.phone) }
  if c.email != none { items.push(link("mailto:" + c.email, c.email)) }
  if c.website != none { items.push(link(c.website, c.website)) }
  for l in c.links { items.push(link(l.url, l.label)) }
  items
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
    spacing: 0.7em,
    heading(level: 1, text(size: 22pt, cv.person.name)),
    ..if cv.person.title != none {
      (text(size: 12pt, fill: muted, cv.person.title),)
    },
    ..if contact-items.len() > 0 {
      (text(size: 9.5pt, fill: muted, contact-items.join[ #h(0.3em)·#h(0.3em) ]),)
    },
  ),
  stroke: none,
))

// Sections --------------------------------------------------------------------

// A line with content on the left and, optionally, muted text flush right.
#let split-line(left, right) = grid(
  columns: (1fr, auto),
  column-gutter: 1em,
  left, if right != none { text(fill: muted, right) },
)

#let section-heading(name) = block(
  above: 3 * unit,
  below: 1.5 * unit,
  sticky: true,
  stack(
    spacing: unit,
    heading(
      level: 2,
      text(size: 11pt, fill: accent, tracking: 0.05em, smallcaps(name)),
    ),
    line(length: 100%, stroke: 0.4pt + accent),
  ),
)

#let entry(e) = block(below: 2 * unit, breakable: false, {
  split-line(strong(e.title), e.timespan)
  let details = (e.organization, e.location).filter(x => x != none)
  if details.len() > 0 {
    block(above: unit, width: measure, text(
      fill: muted,
      emph(details.join(", ")),
    ))
  }
  if e.bullets.len() > 0 {
    block(above: unit, width: measure, list(..e.bullets))
  }
})

// Skills form one grid per section so levels line up next to their names.
#let skills(items) = block(below: 2 * unit, grid(
  columns: (auto, 1fr),
  column-gutter: 2em,
  row-gutter: unit,
  ..items
    .map(s => (s.name, if s.level != none { text(fill: muted, s.level) }))
    .flatten(),
))

#for section in cv.sections {
  section-heading(section.name)
  if section.kind == "entries" {
    for e in section.entries { entry(e) }
  } else if section.kind == "skills" {
    skills(section.items)
  } else if section.kind == "text" {
    block(width: measure, par(section.text))
  }
}

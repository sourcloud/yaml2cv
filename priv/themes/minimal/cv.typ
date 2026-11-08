// yaml2cv "minimal" theme: a reduced single-column layout (ADR 0015).
//
// All CV content comes from cv.json as data; nothing in it is evaluated as
// Typst markup.

#let cv = json("cv.json")

#let accents = (
  black: rgb(0%, 0%, 0%),
  blue: rgb(22%, 45%, 70%),
  burgundy: rgb(60%, 0%, 0%),
  green: rgb(35%, 70%, 30%),
  grey: rgb(55%, 55%, 55%),
  orange: rgb(95%, 55%, 15%),
  purple: rgb(50%, 33%, 80%),
  red: rgb(95%, 20%, 20%),
)
#let accent = accents.at(cv.style.color)
// Dark enough that small and italic text prints solidly on office printers.
#let muted = luma(35%)
// Running text is kept to a comfortable line length (about 75 characters);
// timespans still sit flush with the right margin.
#let measure = 13cm

#set document(title: cv.person.name, author: cv.person.name)
#set page(paper: "a4", margin: (x: 2.2cm, y: 2.2cm))
#set text(font: "Libertinus Serif", size: 10.5pt, lang: "en")
#set par(justify: false, leading: 0.6em)
#set list(indent: 0pt, body-indent: 0.5em, marker: text(fill: muted)[–])

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

#block(below: 1.8em, stack(
  spacing: 0.7em,
  text(size: 22pt, cv.person.name),
  ..if cv.person.title != none {
    (text(size: 12pt, fill: muted, cv.person.title),)
  },
  ..if contact-items.len() > 0 {
    (text(size: 9.5pt, fill: muted, contact-items.join[ #h(0.3em)·#h(0.3em) ]),)
  },
))

// Sections --------------------------------------------------------------------

// A line with content on the left and, optionally, muted text flush right.
#let split-line(left, right) = grid(
  columns: (1fr, auto),
  column-gutter: 1em,
  left, if right != none { text(fill: muted, right) },
)

#let section-heading(name) = block(above: 1.5em, below: 0.8em, sticky: true, {
  text(size: 11pt, fill: accent, tracking: 0.08em, smallcaps(name))
  v(-0.5em)
  line(length: 100%, stroke: 0.4pt + accent)
})

#let entry(e) = block(below: 1em, breakable: false, {
  split-line(strong(e.title), e.timespan)
  let details = (e.organization, e.location).filter(x => x != none)
  if details.len() > 0 {
    block(above: 0.4em, width: measure, text(fill: muted, emph(details.join(", "))))
  }
  if e.bullets.len() > 0 {
    block(above: 0.5em, width: measure, list(spacing: 0.45em, ..e.bullets))
  }
})

// Skills form one grid per section so levels line up next to their names.
#let skills(items) = block(below: 1em, grid(
  columns: (auto, 1fr),
  column-gutter: 2em,
  row-gutter: 0.5em,
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

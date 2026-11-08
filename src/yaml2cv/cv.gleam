//// The CV domain model (schema version 1, see ADR 0007).

import gleam/option.{type Option}

/// A validated CV.
pub type Cv {
  Cv(style: Style, person: Person, contact: Contact, sections: List(Section))
}

/// Visual settings passed to the renderer.
pub type Style {
  Style(theme: Theme, color: Color)
}

pub type Theme {
  Classic
  Minimal
}

pub type Color {
  Black
  Blue
  Burgundy
  Green
  Grey
  Orange
  Purple
  Red
}

pub type Person {
  Person(name: String, title: Option(String), address: Option(String))
}

pub type Contact {
  Contact(
    email: Option(String),
    phone: Option(String),
    website: Option(String),
    links: List(Link),
  )
}

pub type Link {
  Link(label: String, url: String)
}

/// A named CV section; its `content` determines how it is laid out.
pub type Section {
  Section(name: String, content: SectionContent)
}

pub type SectionContent {
  Entries(List(Entry))
  Skills(List(Skill))
  Text(String)
}

/// A dated item such as a job or a degree.
pub type Entry {
  Entry(
    timespan: String,
    title: String,
    organization: Option(String),
    location: Option(String),
    bullets: List(String),
  )
}

/// A named skill or language with an optional level.
pub type Skill {
  Skill(name: String, level: Option(String))
}

/// All themes, in the order they are listed to users.
pub const themes = [#("classic", Classic), #("minimal", Minimal)]

/// All colors, in the order they are listed to users.
pub const colors = [
  #("black", Black),
  #("blue", Blue),
  #("burgundy", Burgundy),
  #("green", Green),
  #("grey", Grey),
  #("orange", Orange),
  #("purple", Purple),
  #("red", Red),
]

/// The name of a theme as written in YAML and used as theme directory name.
pub fn theme_name(theme: Theme) -> String {
  case theme {
    Classic -> "classic"
    Minimal -> "minimal"
  }
}

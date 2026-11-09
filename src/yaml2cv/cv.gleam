//// The CV domain model (schema version 1, see ADR 0007).

import gleam/list
import gleam/option.{type Option}
import gleam/string

/// A validated CV.
pub type Cv {
  Cv(
    language: Language,
    style: Style,
    person: Person,
    contact: Contact,
    sections: List(Section),
  )
}

/// The language of the CV's content: a two-letter lowercase ISO 639-1 code
/// such as `en` or `de` (ADR 0036).
pub opaque type Language {
  Language(code: String)
}

/// The language of a document that does not state one.
pub const default_language = Language("en")

/// Accepts two lowercase ASCII letters, e.g. `de`. The code is checked for
/// its form only, not against a list of languages.
pub fn language(code: String) -> Result(Language, Nil) {
  case string.to_utf_codepoints(code) |> list.map(string.utf_codepoint_to_int) {
    [a, b] if a >= 97 && a <= 122 && b >= 97 && b <= 122 -> Ok(Language(code))
    _ -> Error(Nil)
  }
}

/// The ISO 639-1 code of a language.
pub fn language_code(language: Language) -> String {
  language.code
}

/// Visual settings passed to the renderer.
pub type Style {
  Style(theme: Theme, color: Color, paper: Paper, photo_shape: PhotoShape)
}

pub type Theme {
  Classic
  Minimal
  Studio
  Spotlight
  Cover
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

/// The paper size of the rendered document.
pub type Paper {
  A4
  Letter
}

/// How the profile photo is cropped (ADR 0028).
pub type PhotoShape {
  Rectangle
  Rounded
  Circle
}

pub type Person {
  Person(
    name: String,
    title: Option(String),
    address: Option(String),
    photo: Option(Photo),
  )
}

/// A validated profile photo (ADR 0028).
pub type Photo {
  Photo(format: PhotoFormat, data: BitArray)
}

/// The image formats accepted for profile photos.
pub type PhotoFormat {
  Jpeg
  Png
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

/// The style used for settings a document leaves out.
pub const default_style =
  Style(theme: Classic, color: Blue, paper: A4, photo_shape: Rectangle)

/// All themes, in the order they are listed to users.
pub const themes = [
  #("classic", Classic),
  #("minimal", Minimal),
  #("studio", Studio),
  #("spotlight", Spotlight),
  #("cover", Cover),
]

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

/// All paper sizes, in the order they are listed to users.
pub const papers = [#("a4", A4), #("letter", Letter)]

/// All photo shapes, in the order they are listed to users.
pub const photo_shapes = [
  #("rectangle", Rectangle),
  #("rounded", Rounded),
  #("circle", Circle),
]

/// The name of a theme as written in YAML and used as theme directory name.
pub fn theme_name(theme: Theme) -> String {
  case theme {
    Classic -> "classic"
    Minimal -> "minimal"
    Studio -> "studio"
    Spotlight -> "spotlight"
    Cover -> "cover"
  }
}

//// A lenient model of a CV document for the visual editor (ADR 0024).
////
//// Unlike `Cv`, a draft can hold incomplete documents: every scalar is a
//// string and `""` means absent, so missing or empty required fields are
//// representable. Decoding only rejects what the visual blocks cannot show:
//// syntax errors, unknown keys, wrong node types, unknown style values,
//// section kinds and schema versions. `decode.from_yaml` still validates.

import gleam/float
import gleam/int
import gleam/list
import gleam/string
import yaml2cv/cv
import yaml2cv/cv/decode.{type DecodeError, SchemaError}
import yaml2cv/yaml.{type Node}

/// A CV document as edited in the visual editor.
pub type Draft {
  Draft(style: Style, person: Person, contact: Contact, sections: List(Section))
}

/// Style names as written in YAML; `""` means the default.
pub type Style {
  Style(theme: String, color: String, paper: String)
}

pub type Person {
  Person(name: String, title: String, address: String)
}

pub type Contact {
  Contact(email: String, phone: String, website: String, links: List(Link))
}

pub type Link {
  Link(label: String, url: String)
}

pub type Section {
  Section(name: String, content: Content)
}

/// The content of a section; its kind follows from the variant.
pub type Content {
  Entries(List(Entry))
  Skills(List(Skill))
  Text(String)
}

pub type Entry {
  Entry(
    timespan: String,
    title: String,
    organization: String,
    location: String,
    bullets: List(String),
  )
}

pub type Skill {
  Skill(name: String, level: String)
}

/// The draft with nothing filled in.
pub const empty =
  Draft(
    style: Style(theme: "", color: "", paper: ""),
    person: Person(name: "", title: "", address: ""),
    contact: Contact(email: "", phone: "", website: "", links: []),
    sections: [],
  )

/// An empty link.
pub const blank_link = Link(label: "", url: "")

/// An empty entry.
pub const blank_entry =
  Entry(timespan: "", title: "", organization: "", location: "", bullets: [])

/// An empty skill.
pub const blank_skill = Skill(name: "", level: "")

/// An empty section of the given kind (`entries`, `skills` or `text`);
/// unknown kinds give an entries section, the default kind.
pub fn blank_section(kind: String) -> Section {
  Section(name: "", content: case kind {
    "skills" -> Skills([])
    "text" -> Text("")
    _ -> Entries([])
  })
}

/// The YAML name of a section content's kind.
pub fn kind_name(content: Content) -> String {
  case content {
    Entries(_) -> "entries"
    Skills(_) -> "skills"
    Text(_) -> "text"
  }
}

/// Reads a CV document into a draft, or returns the problems that keep it
/// from being shown as visual blocks. An empty document is an empty draft.
pub fn from_yaml(source: String) -> Result(Draft, List(DecodeError)) {
  case string.trim(source) {
    "" -> Ok(empty)
    _ ->
      case decode.parse_document(source) {
        Error(errors) -> Error(errors)
        Ok(root) ->
          case root_draft(root) {
            #(draft, []) -> Ok(draft)
            #(_, errors) -> Error(errors)
          }
      }
  }
}

// --- Schema ------------------------------------------------------------------

/// A value together with the problems found while reading it.
type Read(a) =
  #(a, List(DecodeError))

type Fields {
  Fields(path: String, entries: List(#(String, Node)))
}

fn root_draft(node: Node) -> Read(Draft) {
  use fields <- object(node, "", empty)
  use _ <- then(version(fields))
  use style <- then(child(fields, "style", empty.style, style))
  use person <- then(child(fields, "person", empty.person, person))
  use contact <- then(child(fields, "contact", empty.contact, contact))
  use sections <- then(list_at(fields, "sections", section))
  use _ <- then(no_unknown_keys(fields, decode.root_keys))
  #(Draft(style:, person:, contact:, sections:), [])
}

fn version(fields: Fields) -> Read(Nil) {
  let path = key_path(fields.path, "schema_version")
  case lookup(fields, "schema_version") {
    Error(Nil) | Ok(yaml.Int(1)) -> #(Nil, [])
    Ok(yaml.Int(version)) ->
      fail(
        Nil,
        path,
        "unsupported version " <> int.to_string(version) <> ", expected 1",
      )
    Ok(_) -> fail(Nil, path, "expected an integer")
  }
}

fn style(node: Node, path: String) -> Read(Style) {
  use fields <- object(node, path, empty.style)
  use theme <- then(choice(fields, "theme", cv.themes))
  use color <- then(choice(fields, "color", cv.colors))
  use paper <- then(choice(fields, "paper", cv.papers))
  use _ <- then(no_unknown_keys(fields, decode.style_keys))
  #(Style(theme:, color:, paper:), [])
}

fn person(node: Node, path: String) -> Read(Person) {
  use fields <- object(node, path, empty.person)
  use name <- then(text(fields, "name"))
  use title <- then(text(fields, "title"))
  use address <- then(text(fields, "address"))
  use _ <- then(no_unknown_keys(fields, decode.person_keys))
  #(Person(name:, title:, address:), [])
}

fn contact(node: Node, path: String) -> Read(Contact) {
  use fields <- object(node, path, empty.contact)
  use email <- then(text(fields, "email"))
  use phone <- then(text(fields, "phone"))
  use website <- then(text(fields, "website"))
  use links <- then(list_at(fields, "links", link))
  use _ <- then(no_unknown_keys(fields, decode.contact_keys))
  #(Contact(email:, phone:, website:, links:), [])
}

fn link(node: Node, path: String) -> Read(Link) {
  use fields <- object(node, path, blank_link)
  use label <- then(text(fields, "label"))
  use url <- then(text(fields, "url"))
  use _ <- then(no_unknown_keys(fields, decode.link_keys))
  #(Link(label:, url:), [])
}

fn section(node: Node, path: String) -> Read(Section) {
  let zero = blank_section("entries")
  use fields <- object(node, path, zero)
  use name <- then(text(fields, "name"))
  let kinds = list.map(decode.section_kinds, fn(kind) { #(kind.0, kind.0) })
  use kind <- then(choice(fields, "kind", kinds))
  let kind = case kind {
    "" -> "entries"
    kind -> kind
  }
  case list.key_find(decode.section_kinds, kind) {
    // An invalid kind was reported; which other keys belong here is unknown.
    Error(Nil) -> #(zero, [])
    Ok(content_key) -> {
      use content <- then(case kind {
        "skills" -> map(list_at(fields, content_key, skill), Skills)
        "text" -> map(text(fields, content_key), Text)
        _ -> map(list_at(fields, content_key, entry), Entries)
      })
      use _ <- then(no_unknown_keys(
        fields,
        list.append(decode.section_keys, [content_key]),
      ))
      #(Section(name:, content:), [])
    }
  }
}

fn entry(node: Node, path: String) -> Read(Entry) {
  use fields <- object(node, path, blank_entry)
  use timespan <- then(text(fields, "timespan"))
  use title <- then(text(fields, "title"))
  use organization <- then(text(fields, "organization"))
  use location <- then(text(fields, "location"))
  use bullets <- then(list_at(fields, "bullets", scalar))
  use _ <- then(no_unknown_keys(fields, decode.entry_keys))
  #(Entry(timespan:, title:, organization:, location:, bullets:), [])
}

fn skill(node: Node, path: String) -> Read(Skill) {
  use fields <- object(node, path, blank_skill)
  use name <- then(text(fields, "name"))
  use level <- then(text(fields, "level"))
  use _ <- then(no_unknown_keys(fields, decode.skill_keys))
  #(Skill(name:, level:), [])
}

// --- Helpers -----------------------------------------------------------------

fn fail(zero: a, path: String, message: String) -> Read(a) {
  #(zero, [SchemaError(path:, message:)])
}

fn then(read: Read(a), next: fn(a) -> Read(b)) -> Read(b) {
  let #(value, errors) = next(read.0)
  #(value, list.append(read.1, errors))
}

fn map(read: Read(a), with: fn(a) -> b) -> Read(b) {
  #(with(read.0), read.1)
}

fn object(
  node: Node,
  path: String,
  zero: a,
  next: fn(Fields) -> Read(a),
) -> Read(a) {
  case node {
    yaml.Map(pairs) ->
      pairs
      |> list.map(fn(pair) { #(key_to_string(pair.0), pair.1) })
      |> Fields(path:, entries: _)
      |> next
    _ -> fail(zero, path, "expected a mapping")
  }
}

fn key_to_string(key: Node) -> String {
  case key {
    yaml.String(key) -> key
    yaml.Int(key) -> int.to_string(key)
    yaml.Float(key) -> float.to_string(key)
    yaml.Bool(True) -> "true"
    yaml.Bool(False) -> "false"
    yaml.Null -> "null"
    yaml.Sequence(_) | yaml.Map(_) -> "<complex key>"
  }
}

/// Looks up a key; an explicit `null` counts as missing.
fn lookup(fields: Fields, key: String) -> Result(Node, Nil) {
  case list.key_find(fields.entries, key) {
    Ok(yaml.Null) -> Error(Nil)
    found -> found
  }
}

/// A nested mapping, or `zero` when the key is missing.
fn child(
  fields: Fields,
  key: String,
  zero: a,
  read: fn(Node, String) -> Read(a),
) -> Read(a) {
  case lookup(fields, key) {
    Ok(node) -> read(node, key_path(fields.path, key))
    Error(Nil) -> #(zero, [])
  }
}

/// A text field; `""` when missing.
fn text(fields: Fields, key: String) -> Read(String) {
  child(fields, key, "", scalar)
}

fn scalar(node: Node, path: String) -> Read(String) {
  case node {
    yaml.String(value) -> #(value, [])
    yaml.Int(value) -> #(int.to_string(value), [])
    yaml.Float(value) -> #(float.to_string(value), [])
    yaml.Null -> #("", [])
    _ -> fail("", path, "expected text")
  }
}

/// One of the names in `options`, or `""` when missing.
fn choice(
  fields: Fields,
  key: String,
  options: List(#(String, a)),
) -> Read(String) {
  use node, path <- child(fields, key, "")
  let names = list.map(options, fn(option) { option.0 })
  case node {
    yaml.String(name) ->
      case list.contains(names, name) {
        True -> #(name, [])
        False -> fail("", path, "expected one of: " <> string.join(names, ", "))
      }
    _ -> fail("", path, "expected one of: " <> string.join(names, ", "))
  }
}

/// A list of items; `[]` when missing.
fn list_at(
  fields: Fields,
  key: String,
  read: fn(Node, String) -> Read(a),
) -> Read(List(a)) {
  use node, path <- child(fields, key, [])
  case node {
    yaml.Sequence(items) -> {
      let read =
        list.index_map(items, fn(item, index) {
          read(item, path <> "[" <> int.to_string(index) <> "]")
        })
      #(
        list.map(read, fn(item) { item.0 }),
        list.flat_map(read, fn(item) { item.1 }),
      )
    }
    _ -> fail([], path, "expected a list")
  }
}

fn no_unknown_keys(fields: Fields, known: List(String)) -> Read(Nil) {
  let errors =
    fields.entries
    |> list.filter(fn(entry) { !list.contains(known, entry.0) })
    |> list.map(fn(entry) {
      SchemaError(path: key_path(fields.path, entry.0), message: "unknown key")
    })
  #(Nil, errors)
}

fn key_path(parent: String, key: String) -> String {
  case parent {
    "" -> key
    _ -> parent <> "." <> key
  }
}

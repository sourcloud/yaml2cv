//// Writes drafts back as canonical YAML (ADR 0024).
////
//// Keys follow the order of the `decode` key lists, empty optional values
//// are left out, empty required values are written as `""`, and every
//// section states its kind. `draft.from_yaml` reads the output back into the
//// same draft.

import gleam/int
import gleam/list
import gleam/string
import yaml2cv/cv/decode
import yaml2cv/cv/draft.{
  type Contact, type Draft, type Entry, type Link, type Person, type Section,
  type Skill, type Style, Entries, Skills, Text,
}
import yaml2cv/yaml

/// Whether an empty value is written (`Required`) or left out.
type Presence {
  Required
  Optional
}

/// The draft as a YAML document.
pub fn to_yaml(draft: Draft) -> String {
  [
    ["schema_version: 1"],
    style(draft.style),
    person(draft.person),
    contact(draft.contact),
    sections(draft.sections),
  ]
  |> list.filter(fn(block) { block != [] })
  |> list.intersperse([""])
  |> list.flatten
  |> string.join("\n")
  |> string.append("\n")
}

fn style(style: Style) -> List(String) {
  let fields =
    list.flatten([
      field(2, "theme", style.theme, Optional),
      field(2, "color", style.color, Optional),
      field(2, "paper", style.paper, Optional),
    ])
  nested("style", fields)
}

fn person(person: Person) -> List(String) {
  ["person:"]
  |> list.append(field(2, "name", person.name, Required))
  |> list.append(field(2, "title", person.title, Optional))
  |> list.append(field(2, "address", person.address, Optional))
}

fn contact(contact: Contact) -> List(String) {
  let links = case contact.links {
    [] -> []
    links -> ["  links:", ..list.flat_map(links, link)]
  }
  let fields =
    list.flatten([
      field(2, "email", contact.email, Optional),
      field(2, "phone", contact.phone, Optional),
      field(2, "website", contact.website, Optional),
      links,
    ])
  nested("contact", fields)
}

fn link(link: Link) -> List(String) {
  item(4, [
    field(6, "label", link.label, Required),
    field(6, "url", link.url, Required),
  ])
}

fn sections(sections: List(Section)) -> List(String) {
  case sections {
    [] -> ["sections: []"]
    sections -> [
      "sections:",
      ..sections
      |> list.map(section)
      |> list.intersperse([""])
      |> list.flatten
    ]
  }
}

fn section(section: Section) -> List(String) {
  let kind = draft.kind_name(section.content)
  let assert Ok(content_key) = list.key_find(decode.section_kinds, kind)
  let content = case section.content {
    Entries(entries) -> items(4, content_key, list.map(entries, entry))
    Skills(skills) -> items(4, content_key, list.map(skills, skill))
    Text(text) -> field(4, content_key, text, Required)
  }
  item(2, [
    field(4, "name", section.name, Required),
    ["    kind: " <> kind],
    content,
  ])
}

fn entry(entry: Entry) -> List(String) {
  let bullets = case entry.bullets {
    [] -> []
    bullets -> [
      "        bullets:",
      ..list.flat_map(bullets, scalar(10, "-", _))
    ]
  }
  item(6, [
    field(8, "timespan", entry.timespan, Required),
    field(8, "title", entry.title, Required),
    field(8, "organization", entry.organization, Optional),
    field(8, "location", entry.location, Optional),
    bullets,
  ])
}

fn skill(skill: Skill) -> List(String) {
  item(6, [
    field(8, "name", skill.name, Required),
    field(8, "level", skill.level, Optional),
  ])
}

// --- Layout ------------------------------------------------------------------

/// A top-level mapping, left out when it has no fields.
fn nested(key: String, fields: List(String)) -> List(String) {
  case fields {
    [] -> []
    fields -> [key <> ":", ..fields]
  }
}

/// A required list of mappings under `key`, `[]` when empty.
fn items(indent: Int, key: String, items: List(List(String))) -> List(String) {
  case items {
    [] -> [spaces(indent) <> key <> ": []"]
    items -> [spaces(indent) <> key <> ":", ..list.flatten(items)]
  }
}

/// A sequence item whose fields are indented two more than `indent`: the
/// first line gets the `- ` marker in place of its leading spaces.
fn item(indent: Int, fields: List(List(String))) -> List(String) {
  case list.flatten(fields) {
    [] -> [spaces(indent) <> "- {}"]
    [first, ..rest] -> [
      spaces(indent) <> "- " <> string.drop_start(first, indent + 2),
      ..rest
    ]
  }
}

fn field(
  indent: Int,
  key: String,
  value: String,
  presence: Presence,
) -> List(String) {
  case value, presence {
    "", Optional -> []
    _, _ -> scalar(indent, key <> ":", value)
  }
}

/// `head` (a `key:` or a `-`) followed by `value`, inline or as a block
/// scalar whose lines are indented two more than `indent`.
fn scalar(indent: Int, head: String, value: String) -> List(String) {
  let prefix = spaces(indent) <> head
  case block_lines(value) {
    Ok(#(indicator, lines)) -> [
      prefix <> " " <> indicator,
      ..list.map(lines, fn(line) {
        case line {
          "" -> ""
          line -> spaces(indent + 2) <> line
        }
      })
    ]
    Error(Nil) -> [prefix <> " " <> inline(value)]
  }
}

fn spaces(count: Int) -> String {
  string.repeat(" ", count)
}

// --- Scalars -----------------------------------------------------------------

/// Multi-line text as a literal block scalar: its indicator with chomping
/// and its lines. Text a block scalar cannot hold exactly is quoted instead.
fn block_lines(value: String) -> Result(#(String, List(String)), Nil) {
  let starts_indented =
    value
    |> string.split("\n")
    |> list.find(fn(line) { line != "" })
    |> fn(line) {
      case line {
        Ok(line) ->
          string.starts_with(line, " ") || string.starts_with(line, "\t")
        Error(Nil) -> True
      }
    }
  case string.contains(value, "\n"), string.contains(value, "\r") {
    True, False if !starts_indented -> {
      let #(indicator, body) = case string.ends_with(value, "\n") {
        False -> #("|-", value)
        True -> {
          let body = string.drop_end(value, 1)
          case string.ends_with(body, "\n") {
            True -> #("|+", body)
            False -> #("|", body)
          }
        }
      }
      Ok(#(indicator, string.split(body, "\n")))
    }
    _, _ -> Error(Nil)
  }
}

/// A single-line scalar: plain when YAML reads it back unchanged as text,
/// double-quoted otherwise.
fn inline(value: String) -> String {
  case is_plain(value) {
    True -> value
    False -> quote(value)
  }
}

/// Values starting with an indicator character are always quoted; for the
/// rest the parser itself decides, in both contexts the emitter writes
/// scalars in, so every YAML rule (numbers, booleans, null, comments,
/// surrounding spaces) is covered. Integers written
/// canonically stay plain: the decoder reads them as the same text.
fn is_plain(value: String) -> Bool {
  case value, string.contains(value, "\n") {
    "", _ | _, True -> False
    _, False -> !starts_with_indicator(value) && parses_as_text(value)
  }
}

fn starts_with_indicator(value: String) -> Bool {
  case string.first(value) {
    Ok(first) -> string.contains("-?:,[]{}#&*!|>'\"%@`", first)
    Error(Nil) -> False
  }
}

fn parses_as_text(value: String) -> Bool {
  case yaml.parse("k: " <> value), yaml.parse("- " <> value) {
    Ok([yaml.Map([#(_, as_value)])]), Ok([yaml.Sequence([as_item])]) ->
      reads_back(as_value, value) && reads_back(as_item, value)
    _, _ -> False
  }
}

fn reads_back(node: yaml.Node, value: String) -> Bool {
  case node {
    yaml.String(read) -> read == value
    yaml.Int(read) -> int.to_string(read) == value
    _ -> False
  }
}

fn quote(value: String) -> String {
  let escaped =
    value
    |> string.replace("\\", "\\\\")
    |> string.replace("\"", "\\\"")
    |> string.replace("\n", "\\n")
    |> string.replace("\r", "\\r")
    |> string.replace("\t", "\\t")
  "\"" <> escaped <> "\""
}

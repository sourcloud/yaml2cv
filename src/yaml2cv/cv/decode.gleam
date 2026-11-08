//// Decoding and validation of CV documents written in YAML (ADR 0007).
////
//// Decoding never stops at the first problem: every decoder yields a value
//// (a placeholder when invalid) together with the errors found so far, so
//// one pass reports every error in the document.

import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import yaml2cv/cv.{
  type Cv, type Entry, type Link, type Section, type Skill, Contact, Cv, Entries,
  Entry, Link, Person, Section, Skill, Skills, Style, Text,
}
import yaml2cv/cv/photo.{type PhotoError}
import yaml2cv/yaml.{type Node}

/// Why a document could not be decoded.
pub type DecodeError {
  /// The input is not valid YAML.
  SyntaxError(message: String, line: Int, column: Int)
  /// The YAML is valid but does not match the schema. `path` locates the
  /// offending value, e.g. `sections[1].entries[0].title`; it is empty for
  /// the document root.
  SchemaError(path: String, problem: SchemaProblem)
  /// The document has more than `max_nodes` nodes after alias expansion.
  DocumentTooLarge(max_nodes: Int)
  /// The document could not be parsed within the time limit, typically
  /// because it is nested very deeply.
  DocumentTooComplex
}

/// What is wrong with a value that does not match the schema.
pub type SchemaProblem {
  ExpectedMapping
  ExpectedOneDocument
  UnsupportedVersion(found: Int, supported: Int)
  ExpectedInteger
  Required
  UnknownKey
  MustNotBeEmpty
  ExpectedText
  ExpectedList
  /// The value is not one of the allowed `names`.
  ExpectedOneOf(names: List(String))
  /// The value is not an acceptable profile photo (ADR 0028).
  InvalidPhoto(PhotoError)
}

/// The English description of a schema problem, as used by the HTTP API.
pub fn describe(problem: SchemaProblem) -> String {
  case problem {
    ExpectedMapping -> "expected a mapping"
    ExpectedOneDocument -> "expected exactly one YAML document"
    UnsupportedVersion(found:, supported:) ->
      "unsupported version "
      <> int.to_string(found)
      <> ", expected "
      <> int.to_string(supported)
    ExpectedInteger -> "expected an integer"
    Required -> "is required"
    UnknownKey -> "unknown key"
    MustNotBeEmpty -> "must not be empty"
    ExpectedText -> "expected text"
    ExpectedList -> "expected a list"
    ExpectedOneOf(names:) -> "expected one of: " <> string.join(names, ", ")
    InvalidPhoto(photo.NotAPhotoDataUri) ->
      "expected a JPEG or PNG image as data:image/jpeg;base64,… "
      <> "or data:image/png;base64,… URI"
    InvalidPhoto(photo.InvalidImage) ->
      "is not a valid image of the declared type"
    InvalidPhoto(photo.TooLarge(max_bytes:)) ->
      "must be at most " <> int.to_string(max_bytes / 1024) <> " KiB"
    InvalidPhoto(photo.TooManyPixels(max_side:)) ->
      "must be at most "
      <> int.to_string(max_side)
      <> " × "
      <> int.to_string(max_side)
      <> " pixels"
  }
}

const supported_version = 1

/// The keys of the document root, in documentation order. The schema
/// reference (`web/schema_help`) is tested against these lists.
pub const root_keys = [
  "schema_version", "style", "person", "contact", "sections",
]

/// The keys of `style`.
pub const style_keys = ["theme", "color", "paper", "photo_shape"]

/// The keys of `person`.
pub const person_keys = ["name", "title", "address", "photo"]

/// The keys of `contact`.
pub const contact_keys = ["email", "phone", "website", "links"]

/// The keys of each `contact.links` item.
pub const link_keys = ["label", "url"]

/// The keys every section has; the content key depends on its kind.
pub const section_keys = ["name", "kind"]

/// Section kinds with the key that holds their content; the first is the
/// default.
pub const section_kinds = [
  #("entries", "entries"),
  #("skills", "items"),
  #("text", "text"),
]

/// The keys of each `entries` item.
pub const entry_keys = [
  "timespan", "title", "organization", "location", "bullets",
]

/// The keys of each `items` item of a skills section.
pub const skill_keys = ["name", "level"]

/// Parses and validates a CV document, returning every error found.
pub fn from_yaml(source: String) -> Result(Cv, List(DecodeError)) {
  use root <- result.try(parse_document(source))
  let Decoded(value:, errors:) = cv().run(root, "")
  case errors {
    [] -> Ok(value)
    _ -> Error(errors)
  }
}

/// Parses `source` into the root node of its single YAML document. Shared
/// with the lenient decoder in `cv/draft`.
pub fn parse_document(source: String) -> Result(Node, List(DecodeError)) {
  case yaml.parse(source) {
    Ok([root]) -> Ok(root)
    Ok([]) -> Error([SchemaError(path: "", problem: ExpectedMapping)])
    Ok(_) ->
      Error([
        SchemaError(path: "", problem: ExpectedOneDocument),
      ])
    Error(yaml.SyntaxError(message:, line:, column:)) ->
      Error([SyntaxError(message:, line:, column:)])
    Error(yaml.TimedOut(..)) -> Error([DocumentTooComplex])
    Error(yaml.TooManyNodes(limit:)) ->
      Error([DocumentTooLarge(max_nodes: limit)])
  }
}

// --- Schema ------------------------------------------------------------------

fn cv() -> Decoder(Cv) {
  let zero =
    Cv(
      style: style().zero,
      person: person().zero,
      contact: contact().zero,
      sections: [],
    )
  use node, path <- Decoder(zero:)
  use fields <- object(node, path, zero)
  use _ <- then(required(fields, "schema_version", schema_version()))
  use style <- then(optional_or(fields, "style", style()))
  use person <- then(required(fields, "person", person()))
  use contact <- then(optional_or(fields, "contact", contact()))
  use sections <- then(required(fields, "sections", list_of(section())))
  use _ <- then(no_unknown_keys(fields, root_keys))
  succeed(Cv(style:, person:, contact:, sections:))
}

fn schema_version() -> Decoder(Int) {
  use node, path <- Decoder(zero: supported_version)
  case node {
    yaml.Int(version) if version == supported_version -> succeed(version)
    yaml.Int(version) ->
      fail(
        version,
        path,
        UnsupportedVersion(found: version, supported: supported_version),
      )
    _ -> fail(supported_version, path, ExpectedInteger)
  }
}

fn style() -> Decoder(cv.Style) {
  let zero = cv.default_style
  use node, path <- Decoder(zero:)
  use fields <- object(node, path, zero)
  use theme <- then(optional_or(fields, "theme", one_of(cv.themes, zero.theme)))
  use color <- then(optional_or(fields, "color", one_of(cv.colors, zero.color)))
  use paper <- then(optional_or(fields, "paper", one_of(cv.papers, zero.paper)))
  use photo_shape <- then(optional_or(
    fields,
    "photo_shape",
    one_of(cv.photo_shapes, zero.photo_shape),
  ))
  use _ <- then(no_unknown_keys(fields, style_keys))
  succeed(Style(theme:, color:, paper:, photo_shape:))
}

fn person() -> Decoder(cv.Person) {
  let zero = Person(name: "", title: None, address: None, photo: None)
  use node, path <- Decoder(zero:)
  use fields <- object(node, path, zero)
  use name <- then(required(fields, "name", text()))
  use title <- then(optional(fields, "title", text()))
  use address <- then(optional(fields, "address", text()))
  use photo <- then(optional(fields, "photo", photo()))
  use _ <- then(no_unknown_keys(fields, person_keys))
  succeed(Person(name:, title:, address:, photo:))
}

fn photo() -> Decoder(cv.Photo) {
  let zero = cv.Photo(format: cv.Jpeg, data: <<>>)
  use node, path <- Decoder(zero:)
  case node {
    yaml.String(value) ->
      case photo.from_data_uri(string.trim(value)) {
        Ok(photo) -> succeed(photo)
        Error(error) -> fail(zero, path, InvalidPhoto(error))
      }
    _ -> fail(zero, path, InvalidPhoto(photo.NotAPhotoDataUri))
  }
}

fn contact() -> Decoder(cv.Contact) {
  let zero = Contact(email: None, phone: None, website: None, links: [])
  use node, path <- Decoder(zero:)
  use fields <- object(node, path, zero)
  use email <- then(optional(fields, "email", text()))
  use phone <- then(optional(fields, "phone", text()))
  use website <- then(optional(fields, "website", text()))
  use links <- then(optional_or(fields, "links", list_of(link())))
  use _ <- then(no_unknown_keys(fields, contact_keys))
  succeed(Contact(email:, phone:, website:, links:))
}

fn link() -> Decoder(Link) {
  let zero = Link(label: "", url: "")
  use node, path <- Decoder(zero:)
  use fields <- object(node, path, zero)
  use label <- then(required(fields, "label", text()))
  use url <- then(required(fields, "url", text()))
  use _ <- then(no_unknown_keys(fields, link_keys))
  succeed(Link(label:, url:))
}

/// Section kinds as written in YAML. `UnknownKind` only stands in for an
/// invalid `kind` value so decoding can carry on.
type Kind {
  EntriesKind
  SkillsKind
  TextKind
  UnknownKind
}

fn section() -> Decoder(Section) {
  let zero = Section(name: "", content: Text(""))
  use node, path <- Decoder(zero:)
  use fields <- object(node, path, zero)
  use name <- then(required(fields, "name", text()))
  let kinds = [
    #("entries", EntriesKind),
    #("skills", SkillsKind),
    #("text", TextKind),
  ]
  use kind <- then(optional(fields, "kind", one_of(kinds, UnknownKind)))
  let content = case option.unwrap(kind, EntriesKind) {
    EntriesKind ->
      Some(#(
        "entries",
        map(required(fields, "entries", list_of(entry())), Entries),
      ))
    SkillsKind ->
      Some(#("items", map(required(fields, "items", list_of(skill())), Skills)))
    TextKind -> Some(#("text", map(required(fields, "text", text()), Text)))
    UnknownKind -> None
  }
  case content {
    // The kind itself is invalid; which other keys belong here is unknown.
    None -> succeed(zero)
    Some(#(content_key, content)) -> {
      use content <- then(content)
      use _ <- then(no_unknown_keys(
        fields,
        list.append(section_keys, [content_key]),
      ))
      succeed(Section(name:, content:))
    }
  }
}

fn entry() -> Decoder(Entry) {
  let zero =
    Entry(
      timespan: "",
      title: "",
      organization: None,
      location: None,
      bullets: [],
    )
  use node, path <- Decoder(zero:)
  use fields <- object(node, path, zero)
  use timespan <- then(required(fields, "timespan", text()))
  use title <- then(required(fields, "title", text()))
  use organization <- then(optional(fields, "organization", text()))
  use location <- then(optional(fields, "location", text()))
  use bullets <- then(optional_or(fields, "bullets", list_of(text())))
  use _ <- then(no_unknown_keys(fields, entry_keys))
  succeed(Entry(timespan:, title:, organization:, location:, bullets:))
}

fn skill() -> Decoder(Skill) {
  let zero = Skill(name: "", level: None)
  use node, path <- Decoder(zero:)
  use fields <- object(node, path, zero)
  use name <- then(required(fields, "name", text()))
  use level <- then(optional(fields, "level", text()))
  use _ <- then(no_unknown_keys(fields, skill_keys))
  succeed(Skill(name:, level:))
}

// --- Combinators -------------------------------------------------------------

/// A decoded value plus the errors found while decoding it. When `errors` is
/// non-empty, `value` is a placeholder.
type Decoded(a) {
  Decoded(value: a, errors: List(DecodeError))
}

/// Decodes a YAML node found at a path. `zero` is the placeholder used when
/// the node is missing or invalid.
type Decoder(a) {
  Decoder(zero: a, run: fn(Node, String) -> Decoded(a))
}

/// The keys of a YAML mapping, in document order.
type Fields {
  Fields(path: String, entries: List(#(String, Node)))
}

fn succeed(value: a) -> Decoded(a) {
  Decoded(value:, errors: [])
}

fn fail(zero: a, path: String, problem: SchemaProblem) -> Decoded(a) {
  Decoded(value: zero, errors: [SchemaError(path:, problem:)])
}

fn then(decoded: Decoded(a), next: fn(a) -> Decoded(b)) -> Decoded(b) {
  let Decoded(value:, errors:) = next(decoded.value)
  Decoded(value:, errors: list.append(decoded.errors, errors))
}

fn map(decoded: Decoded(a), with: fn(a) -> b) -> Decoded(b) {
  Decoded(value: with(decoded.value), errors: decoded.errors)
}

fn object(
  node: Node,
  path: String,
  zero: a,
  next: fn(Fields) -> Decoded(a),
) -> Decoded(a) {
  case node {
    yaml.Map(pairs) ->
      pairs
      |> list.map(fn(pair) { #(key_to_string(pair.0), pair.1) })
      |> Fields(path:, entries: _)
      |> next
    _ -> fail(zero, path, ExpectedMapping)
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
fn lookup(fields: Fields, key: String) -> Option(Node) {
  case list.key_find(fields.entries, key) {
    Ok(yaml.Null) | Error(Nil) -> None
    Ok(node) -> Some(node)
  }
}

fn required(fields: Fields, key: String, decoder: Decoder(a)) -> Decoded(a) {
  let path = key_path(fields.path, key)
  case lookup(fields, key) {
    Some(node) -> decoder.run(node, path)
    None -> fail(decoder.zero, path, Required)
  }
}

fn optional(
  fields: Fields,
  key: String,
  decoder: Decoder(a),
) -> Decoded(Option(a)) {
  case lookup(fields, key) {
    Some(node) -> map(decoder.run(node, key_path(fields.path, key)), Some)
    None -> succeed(None)
  }
}

/// Like `optional`, but falls back to the decoder's `zero` when missing.
fn optional_or(fields: Fields, key: String, decoder: Decoder(a)) -> Decoded(a) {
  map(optional(fields, key, decoder), option.unwrap(_, decoder.zero))
}

fn no_unknown_keys(fields: Fields, known: List(String)) -> Decoded(Nil) {
  let errors =
    fields.entries
    |> list.filter(fn(entry) { !list.contains(known, entry.0) })
    |> list.map(fn(entry) {
      SchemaError(path: key_path(fields.path, entry.0), problem: UnknownKey)
    })
  Decoded(value: Nil, errors:)
}

fn text() -> Decoder(String) {
  use node, path <- Decoder(zero: "")
  case node {
    yaml.String(value) ->
      case string.trim(value) {
        "" -> fail("", path, MustNotBeEmpty)
        value -> succeed(value)
      }
    yaml.Int(value) -> succeed(int.to_string(value))
    yaml.Float(value) -> succeed(float.to_string(value))
    _ -> fail("", path, ExpectedText)
  }
}

fn list_of(decoder: Decoder(a)) -> Decoder(List(a)) {
  use node, path <- Decoder(zero: [])
  case node {
    yaml.Sequence(items) -> {
      let decoded =
        list.index_map(items, fn(item, index) {
          decoder.run(item, path <> "[" <> int.to_string(index) <> "]")
        })
      Decoded(
        value: list.map(decoded, fn(item) { item.value }),
        errors: list.flat_map(decoded, fn(item) { item.errors }),
      )
    }
    _ -> fail([], path, ExpectedList)
  }
}

fn one_of(options: List(#(String, a)), zero: a) -> Decoder(a) {
  use node, path <- Decoder(zero:)
  let found = case node {
    yaml.String(name) -> list.key_find(options, name)
    _ -> Error(Nil)
  }
  case found {
    Ok(value) -> succeed(value)
    Error(Nil) ->
      fail(
        zero,
        path,
        ExpectedOneOf(list.map(options, fn(option) { option.0 })),
      )
  }
}

fn key_path(parent: String, key: String) -> String {
  case parent {
    "" -> key
    _ -> parent <> "." <> key
  }
}

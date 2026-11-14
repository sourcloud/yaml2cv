//// In-app reference of the CV schema (ADR 0022), shown in a dialog on the
//// editor page. Choices and defaults come from `cv`; the documented keys are
//// tested against the lists `cv/decode` validates with. Descriptions come
//// from the locale's `SchemaTexts` (ADR 0025).

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import lustre/element.{type Element}
import lustre/element/html
import yaml2cv/cv
import yaml2cv/cv/decode
import yaml2cv/web/i18n/texts.{type SchemaTexts}
import yaml2cv/web/ui/dialog
import yaml2cv/web/ui/field_table.{Row}

/// The id of the dialog; a button with `data-dialog-open` set to it opens it.
pub const dialog_id = "schema-help"

/// One mapping of the schema and its keys.
pub type Group(message) {
  Group(
    id: String,
    title: String,
    intro: List(Element(message)),
    fields: List(field_table.Row(message)),
  )
}

/// The schema reference dialog, closed with a button labelled `close`.
pub fn view(t: SchemaTexts, close close: String) -> Element(message) {
  dialog.view(id: dialog_id, title: t.title, close:, body: [
    html.p([], rich(t.intro)),
    ..list.flat_map(groups(t), group_view(t, _))
  ])
}

fn group_view(t: SchemaTexts, group: Group(message)) -> List(Element(message)) {
  [
    html.h3([], [html.text(group.title)]),
    html.p([], group.intro),
    field_table.view(
      key_header: t.key_header,
      requirement_header: t.requirement_header,
      description_header: t.description_header,
      rows: group.fields,
    ),
  ]
}

/// One documented key. `description` marks code with backticks; `values`
/// lists the allowed values when they are a fixed set.
pub type Field {
  Field(
    key: String,
    requirement: String,
    description: String,
    values: List(String),
    default: Option(String),
  )
}

/// One mapping of the schema: where it sits in the document (`path`, with
/// `[]` for the items of a list, empty for the root) and its keys.
pub type Mapping {
  Mapping(
    id: String,
    path: String,
    title: String,
    intro: String,
    fields: List(Field),
  )
}

/// Every documented mapping, in reading order.
pub fn mappings(t: SchemaTexts) -> List(Mapping) {
  let style = cv.default_style
  let required = fn(key, description) {
    Field(
      key:,
      requirement: t.required,
      description:,
      values: [],
      default: None,
    )
  }
  let optional = fn(key, description) {
    Field(
      key:,
      requirement: t.optional,
      description:,
      values: [],
      default: None,
    )
  }
  let mapping = fn(id, path, intro, fields) {
    Mapping(id:, path:, title: path, intro:, fields:)
  }
  [
    Mapping(
      id: "document",
      path: "",
      title: t.document_title,
      intro: t.document_intro,
      fields: [
        required("schema_version", t.schema_version),
        optional("language", t.language),
        optional("style", t.style_key),
        required("person", t.person_key),
        optional("contact", t.contact_key),
        required("sections", t.sections_key),
      ],
    ),
    mapping("style", "style", t.style_intro, [
      choice(t, "theme", t.theme, cv.themes, style.theme),
      choice(t, "color", t.color, cv.colors, style.color),
      choice(t, "paper", t.paper, cv.papers, style.paper),
      choice(
        t,
        "photo_shape",
        t.photo_shape,
        cv.photo_shapes,
        style.photo_shape,
      ),
    ]),
    mapping("person", "person", t.person_intro, [
      required("name", t.person_name),
      optional("title", t.person_title),
      optional("address", t.person_address),
      optional("photo", t.person_photo),
    ]),
    mapping("contact", "contact", t.contact_intro, [
      optional("email", t.email),
      optional("phone", t.phone),
      optional("website", t.website),
      optional("links", t.links),
    ]),
    mapping("link", "contact.links[]", t.link_intro, [
      required("label", t.link_label),
      required("url", t.link_url),
    ]),
    mapping("section", "sections[]", t.section_intro, [
      required("name", t.section_name),
      choice(
        t,
        "kind",
        t.section_kind,
        list.map(decode.section_kinds, fn(kind) { #(kind.0, kind.0) }),
        default_kind(),
      ),
      ..list.map(decode.section_kinds, section_content(t, _))
    ]),
    mapping("entry", "sections[].entries[]", t.entry_intro, [
      required("timespan", t.timespan),
      required("title", t.entry_title),
      optional("organization", t.organization),
      optional("location", t.location),
      optional("bullets", t.bullets),
    ]),
    mapping("skill", "sections[].items[]", t.skill_intro, [
      required("name", t.skill_name),
      optional("level", t.skill_level),
    ]),
  ]
}

/// Every documented mapping as shown in the reference, in reading order.
pub fn groups(t: SchemaTexts) -> List(Group(message)) {
  use mapping <- list.map(mappings(t))
  Group(
    id: mapping.id,
    title: mapping.title,
    intro: rich(mapping.intro),
    fields: list.map(mapping.fields, row(t, _)),
  )
}

fn row(t: SchemaTexts, field: Field) -> field_table.Row(message) {
  let description = case field.values {
    [] -> rich(field.description)
    values ->
      list.append(
        rich(field.description <> " "),
        choices(t, values, field.default),
      )
  }
  Row(key: field.key, requirement: field.requirement, description:)
}

/// An optional key whose value is one of `options`.
fn choice(
  t: SchemaTexts,
  key: String,
  description: String,
  options: List(#(String, a)),
  default: a,
) -> Field {
  Field(
    key:,
    requirement: t.optional,
    description:,
    values: list.map(options, fn(option) { option.0 }),
    default: list.find(options, fn(option) { option.1 == default })
      |> result.map(fn(option) { option.0 })
      |> option.from_result,
  )
}

fn section_content(t: SchemaTexts, kind: #(String, String)) -> Field {
  let #(kind, key) = kind
  let description = case key {
    "entries" -> t.section_entries
    "items" -> t.section_items
    _ -> t.section_text
  }
  Field(
    key:,
    requirement: t.if_kind(kind),
    description:,
    values: [],
    default: None,
  )
}

fn default_kind() -> String {
  case decode.section_kinds {
    [#(kind, _), ..] -> kind
    [] -> ""
  }
}

/// Text with the parts between backticks shown as code.
pub fn rich(text: String) -> List(Element(message)) {
  text
  |> string.split("`")
  |> list.index_map(fn(part, index) {
    case index % 2, part {
      _, "" -> element.none()
      0, _ -> html.text(part)
      _, _ -> code(part)
    }
  })
  |> list.filter(fn(part) { part != element.none() })
}

fn code(text: String) -> Element(message) {
  html.code([], [html.text(text)])
}

/// "One of: a, b. Default: a." with every name as code.
fn choices(
  t: SchemaTexts,
  values: List(String),
  default: Option(String),
) -> List(Element(message)) {
  let names =
    values
    |> list.map(code)
    |> list.intersperse(html.text(", "))
  let default_name = case default {
    Some(name) -> [
      html.text(" " <> t.default <> " "),
      code(name),
      html.text("."),
    ]
    None -> []
  }
  list.flatten([
    [html.text(t.one_of <> " ")],
    names,
    [html.text(".")],
    default_name,
  ])
}

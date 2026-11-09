//// In-app reference of the CV schema (ADR 0022), shown in a dialog on the
//// editor page. Choices and defaults come from `cv`; the documented keys are
//// tested against the lists `cv/decode` validates with. Descriptions come
//// from the locale's `SchemaTexts` (ADR 0025).

import gleam/list
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

/// Every documented mapping, in reading order.
pub fn groups(t: SchemaTexts) -> List(Group(message)) {
  let style = cv.default_style
  let required = fn(key, description) {
    Row(key:, requirement: t.required, description: rich(description))
  }
  let optional = fn(key, description) {
    Row(key:, requirement: t.optional, description: rich(description))
  }
  [
    Group(
      id: "document",
      title: t.document_title,
      intro: rich(t.document_intro),
      fields: [
        required("schema_version", t.schema_version),
        optional("language", t.language),
        optional("style", t.style_key),
        required("person", t.person_key),
        optional("contact", t.contact_key),
        required("sections", t.sections_key),
      ],
    ),
    Group(id: "style", title: "style", intro: rich(t.style_intro), fields: [
      optional_choice(t, "theme", t.theme, cv.themes, style.theme),
      optional_choice(t, "color", t.color, cv.colors, style.color),
      optional_choice(t, "paper", t.paper, cv.papers, style.paper),
      optional_choice(
        t,
        "photo_shape",
        t.photo_shape,
        cv.photo_shapes,
        style.photo_shape,
      ),
    ]),
    Group(id: "person", title: "person", intro: rich(t.person_intro), fields: [
      required("name", t.person_name),
      optional("title", t.person_title),
      optional("address", t.person_address),
      optional("photo", t.person_photo),
    ]),
    Group(
      id: "contact",
      title: "contact",
      intro: rich(t.contact_intro),
      fields: [
        optional("email", t.email),
        optional("phone", t.phone),
        optional("website", t.website),
        optional("links", t.links),
      ],
    ),
    Group(
      id: "link",
      title: "contact.links[]",
      intro: rich(t.link_intro),
      fields: [required("label", t.link_label), required("url", t.link_url)],
    ),
    Group(
      id: "section",
      title: "sections[]",
      intro: rich(t.section_intro),
      fields: [
        required("name", t.section_name),
        optional_choice(
          t,
          "kind",
          t.section_kind,
          list.map(decode.section_kinds, fn(kind) { #(kind.0, kind.0) }),
          default_kind(),
        ),
        ..list.map(decode.section_kinds, section_content(t, _))
      ],
    ),
    Group(
      id: "entry",
      title: "sections[].entries[]",
      intro: rich(t.entry_intro),
      fields: [
        required("timespan", t.timespan),
        required("title", t.entry_title),
        optional("organization", t.organization),
        optional("location", t.location),
        optional("bullets", t.bullets),
      ],
    ),
    Group(
      id: "skill",
      title: "sections[].items[]",
      intro: rich(t.skill_intro),
      fields: [
        required("name", t.skill_name),
        optional("level", t.skill_level),
      ],
    ),
  ]
}

/// An optional key whose value is one of `options`.
fn optional_choice(
  t: SchemaTexts,
  key: String,
  description: String,
  options: List(#(String, a)),
  default: a,
) -> field_table.Row(message) {
  Row(
    key:,
    requirement: t.optional,
    description: list.append(
      rich(description <> " "),
      choices(t, options, default),
    ),
  )
}

fn section_content(
  t: SchemaTexts,
  kind: #(String, String),
) -> field_table.Row(message) {
  let #(kind, key) = kind
  let description = case key {
    "entries" -> t.section_entries
    "items" -> t.section_items
    _ -> t.section_text
  }
  Row(key:, requirement: t.if_kind(kind), description: rich(description))
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
  options: List(#(String, a)),
  default: a,
) -> List(Element(message)) {
  let names =
    options
    |> list.map(fn(option) { code(option.0) })
    |> list.intersperse(html.text(", "))
  let default_name = case
    list.find(options, fn(option) { option.1 == default })
  {
    Ok(#(name, _)) -> [
      html.text(" " <> t.default <> " "),
      code(name),
      html.text("."),
    ]
    Error(Nil) -> []
  }
  list.flatten([
    [html.text(t.one_of <> " ")],
    names,
    [html.text(".")],
    default_name,
  ])
}

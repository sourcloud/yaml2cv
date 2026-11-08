//// In-app reference of the CV schema (ADR 0022), shown in a dialog on the
//// editor page. Choices and defaults come from `cv`; the documented keys are
//// tested against the lists `cv/decode` validates with.

import gleam/list
import lustre/element.{type Element}
import lustre/element/html
import yaml2cv/cv
import yaml2cv/cv/decode
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

/// The schema reference dialog.
pub fn view() -> Element(message) {
  dialog.view(id: dialog_id, title: "CV schema", body: [
    html.p([], [
      html.text(
        "A CV is one YAML document. Keys not listed here are errors. Text values may be strings or numbers and must not be empty. Problems are listed below the editor while you type.",
      ),
    ]),
    ..list.flat_map(groups(), group_view)
  ])
}

fn group_view(group: Group(message)) -> List(Element(message)) {
  [
    html.h3([], [html.text(group.title)]),
    html.p([], group.intro),
    field_table.view(group.fields),
  ]
}

/// Every documented mapping, in reading order.
pub fn groups() -> List(Group(message)) {
  let style = cv.default_style
  [
    Group(
      id: "document",
      title: "Document",
      intro: [html.text("The top level of the document.")],
      fields: [
        required("schema_version", [
          html.text("Schema version. Must be "),
          code("1"),
          html.text("."),
        ]),
        optional("style", [
          html.text("Visual settings; see "),
          code("style"),
          html.text("."),
        ]),
        required("person", [
          html.text("Who the CV is about; see "),
          code("person"),
          html.text("."),
        ]),
        optional("contact", [
          html.text("Contact details; see "),
          code("contact"),
          html.text("."),
        ]),
        required("sections", [
          html.text("The sections in the order they appear; see "),
          code("sections[]"),
          html.text(". May be empty: "),
          code("[]"),
          html.text("."),
        ]),
      ],
    ),
    Group(
      id: "style",
      title: "style",
      intro: [html.text("How the CV looks. Every key has a default.")],
      fields: [
        optional("theme", [
          html.text("Layout and typography. "),
          ..choices(cv.themes, style.theme)
        ]),
        optional("color", [
          html.text("Accent colour. "),
          ..choices(cv.colors, style.color)
        ]),
        optional("paper", [
          html.text("Paper size. "),
          ..choices(cv.papers, style.paper)
        ]),
      ],
    ),
    Group(
      id: "person",
      title: "person",
      intro: [html.text("Shown at the top of the CV.")],
      fields: [
        required("name", [html.text("Full name, shown as the heading.")]),
        optional("title", [html.text("Job title or tagline under the name.")]),
        optional("address", [html.text("Postal address.")]),
      ],
    ),
    Group(
      id: "contact",
      title: "contact",
      intro: [html.text("How to reach you. Every key is optional.")],
      fields: [
        optional("email", [html.text("Email address.")]),
        optional("phone", [html.text("Phone number.")]),
        optional("website", [html.text("Website address.")]),
        optional("links", [
          html.text("Further links; see "),
          code("contact.links[]"),
          html.text("."),
        ]),
      ],
    ),
    Group(
      id: "link",
      title: "contact.links[]",
      intro: [html.text("Each item of the links list.")],
      fields: [
        required("label", [
          html.text("Text shown, for example "),
          code("GitHub"),
          html.text("."),
        ]),
        required("url", [html.text("Address the link points to.")]),
      ],
    ),
    Group(
      id: "section",
      title: "sections[]",
      intro: [
        html.text(
          "Each section has a name and a kind; the kind decides which key holds its content.",
        ),
      ],
      fields: [
        required("name", [html.text("Section heading.")]),
        optional(
          "kind",
          [html.text("What the section contains. ")]
            |> list.append(choices(
              list.map(decode.section_kinds, fn(kind) { #(kind.0, kind.0) }),
              default_kind(),
            )),
        ),
        ..list.map(decode.section_kinds, section_content)
      ],
    ),
    Group(
      id: "entry",
      title: "sections[].entries[]",
      intro: [html.text("A dated item such as a job or a degree.")],
      fields: [
        required("timespan", [
          html.text("Period as text, for example "),
          code("2019 – 2023"),
          html.text(" or "),
          code("since 2020"),
          html.text("."),
        ]),
        required("title", [html.text("Role, degree or similar.")]),
        optional("organization", [html.text("Employer, school or similar.")]),
        optional("location", [html.text("City or place.")]),
        optional("bullets", [
          html.text("List of text lines shown as bullet points."),
        ]),
      ],
    ),
    Group(
      id: "skill",
      title: "sections[].items[]",
      intro: [html.text("A skill or language.")],
      fields: [
        required("name", [html.text("Name of the skill or language.")]),
        optional("level", [
          html.text("Level as text, for example "),
          code("Fluent"),
          html.text("."),
        ]),
      ],
    ),
  ]
}

fn section_content(kind: #(String, String)) -> field_table.Row(message) {
  let #(kind, key) = kind
  let description = case key {
    "entries" -> [
      html.text("List of dated items; see "),
      code("sections[].entries[]"),
      html.text("."),
    ]
    "items" -> [
      html.text("List of skills or languages; see "),
      code("sections[].items[]"),
      html.text("."),
    ]
    _ -> [html.text("A paragraph of free text.")]
  }
  Row(key:, requirement: "if kind is " <> kind, description:)
}

fn default_kind() -> String {
  case decode.section_kinds {
    [#(kind, _), ..] -> kind
    [] -> ""
  }
}

fn required(
  key: String,
  description: List(Element(message)),
) -> field_table.Row(message) {
  Row(key:, requirement: "required", description:)
}

fn optional(
  key: String,
  description: List(Element(message)),
) -> field_table.Row(message) {
  Row(key:, requirement: "optional", description:)
}

fn code(text: String) -> Element(message) {
  html.code([], [html.text(text)])
}

/// "One of: a, b. Default: a." with every name as code.
fn choices(options: List(#(String, a)), default: a) -> List(Element(message)) {
  let names =
    options
    |> list.map(fn(option) { code(option.0) })
    |> list.intersperse(html.text(", "))
  let default_name = case
    list.find(options, fn(option) { option.1 == default })
  {
    Ok(#(name, _)) -> [html.text(" Default: "), code(name), html.text(".")]
    Error(Nil) -> []
  }
  list.flatten([[html.text("One of: ")], names, [html.text(".")], default_name])
}

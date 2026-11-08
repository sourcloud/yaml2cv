//// Reference table of document keys
//// (`priv/static/css/components/field-table.css`).

import gleam/list
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

/// One documented key.
pub type Row(message) {
  Row(key: String, requirement: String, description: List(Element(message)))
}

/// A table of keys with whether they are required and what they mean,
/// under the given column headers.
pub fn view(
  key_header key_header: String,
  requirement_header requirement_header: String,
  description_header description_header: String,
  rows rows: List(Row(message)),
) -> Element(message) {
  html.table([attribute.class("ui-field-table")], [
    html.thead([], [
      html.tr([], [
        html.th([attribute.scope("col")], [html.text(key_header)]),
        html.th([attribute.scope("col")], [html.text(requirement_header)]),
        html.th([attribute.scope("col")], [html.text(description_header)]),
      ]),
    ]),
    html.tbody(
      [],
      list.map(rows, fn(row) {
        html.tr([], [
          html.th([attribute.scope("row")], [
            html.code([attribute.class("ui-field-table__key")], [
              html.text(row.key),
            ]),
          ]),
          html.td([attribute.class("ui-field-table__requirement")], [
            html.text(row.requirement),
          ]),
          html.td([], row.description),
        ])
      }),
    ),
  ])
}

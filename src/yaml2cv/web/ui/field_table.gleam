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

/// A table of keys with whether they are required and what they mean.
pub fn view(rows: List(Row(message))) -> Element(message) {
  html.table([attribute.class("ui-field-table")], [
    html.thead([], [
      html.tr([], [
        html.th([attribute.scope("col")], [html.text("Key")]),
        html.th([attribute.scope("col")], [html.text("Required")]),
        html.th([attribute.scope("col")], [html.text("Description")]),
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

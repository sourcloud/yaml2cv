//// Validation error list (`priv/static/css/components/error-list.css`).

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

/// One listed error. An empty `location` refers to the whole document.
pub type Item {
  Item(location: String, message: String, target: Option(Target))
}

/// A position in a text field the error points to; `line` and `column` are
/// 1-based. `editor.js` moves the cursor there when the location is clicked.
pub type Target {
  Target(field: String, line: Int, column: Int)
}

/// Lists errors; locations with a target become buttons that jump to it.
/// An empty location shows `document_label`; jump buttons are titled
/// `jump_label`.
pub fn view(
  errors errors: List(Item),
  document_label document_label: String,
  jump_label jump_label: String,
) -> Element(message) {
  html.ul(
    [attribute.class("ui-error-list")],
    list.map(errors, fn(error) {
      let Item(location:, message:, target:) = error
      html.li([attribute.class("ui-error-list__item")], [
        location_view(location, target, document_label, jump_label),
        html.span([attribute.class("ui-error-list__message")], [
          html.text(message),
        ]),
      ])
    }),
  )
}

fn location_view(
  location: String,
  target: Option(Target),
  document_label: String,
  jump_label: String,
) -> Element(message) {
  let text =
    html.text(case location {
      "" -> document_label
      _ -> location
    })
  case target {
    None -> html.code([attribute.class("ui-error-list__location")], [text])
    Some(Target(field:, line:, column:)) ->
      html.button(
        [
          attribute.type_("button"),
          attribute.class("ui-error-list__location ui-error-list__jump"),
          attribute.data("jump-field", field),
          attribute.data("jump-line", int.to_string(line)),
          attribute.data("jump-column", int.to_string(column)),
          attribute.title(jump_label),
        ],
        [html.code([], [text])],
      )
  }
}

//// Validation error list (`priv/static/css/components/error-list.css`).

import gleam/list
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

/// Lists errors as `#(location, message)` pairs; an empty location refers to
/// the whole document.
pub fn view(errors: List(#(String, String))) -> Element(message) {
  html.ul(
    [attribute.class("ui-error-list")],
    list.map(errors, fn(error) {
      let #(location, message) = error
      html.li([attribute.class("ui-error-list__item")], [
        html.code([attribute.class("ui-error-list__location")], [
          html.text(case location {
            "" -> "document"
            _ -> location
          }),
        ]),
        html.span([attribute.class("ui-error-list__message")], [
          html.text(message),
        ]),
      ])
    }),
  )
}

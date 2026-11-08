//// Stack of rendered page images (`priv/static/css/components/page-stack.css`).

import gleam/bit_array
import gleam/int
import gleam/list
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

/// Shows PNG pages, embedded as `data:` URIs, one below the other.
pub fn view(pages: List(BitArray)) -> Element(message) {
  html.div(
    [attribute.class("ui-page-stack")],
    list.index_map(pages, fn(png, index) {
      html.img([
        attribute.class("ui-page-stack__page"),
        attribute.src(
          "data:image/png;base64," <> bit_array.base64_encode(png, True),
        ),
        attribute.alt("Page " <> int.to_string(index + 1)),
      ])
    }),
  )
}

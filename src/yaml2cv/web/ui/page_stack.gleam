//// Stack of rendered page images (`priv/static/css/components/page-stack.css`).

import gleam/bit_array
import gleam/int
import gleam/list
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

/// Shows SVG pages, embedded as `data:` URIs, one below the other. As images
/// they cannot run scripts or follow links (ADR 0019).
pub fn view(pages: List(BitArray)) -> Element(message) {
  html.div(
    [attribute.class("ui-page-stack")],
    list.index_map(pages, fn(svg, index) {
      html.img([
        attribute.class("ui-page-stack__page"),
        attribute.src(
          "data:image/svg+xml;base64," <> bit_array.base64_encode(svg, True),
        ),
        attribute.alt("Page " <> int.to_string(index + 1)),
      ])
    }),
  )
}

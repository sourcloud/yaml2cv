//// Stack of rendered page images (`priv/static/css/components/page-stack.css`).

import gleam/bit_array
import gleam/list
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

/// Shows SVG pages, embedded as `data:` URIs, one below the other. As images
/// they cannot run scripts or follow links (ADR 0019). `page_label` gives
/// the alternative text of page `n`, counted from 1.
pub fn view(
  pages pages: List(BitArray),
  page_label page_label: fn(Int) -> String,
) -> Element(message) {
  html.div(
    [attribute.class("ui-page-stack")],
    list.index_map(pages, fn(svg, index) {
      html.img([
        attribute.class("ui-page-stack__page"),
        attribute.src(
          "data:image/svg+xml;base64," <> bit_array.base64_encode(svg, True),
        ),
        attribute.alt(page_label(index + 1)),
      ])
    }),
  )
}

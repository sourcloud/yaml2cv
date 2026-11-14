//// Stack of rendered page images (`priv/static/css/components/page-stack.css`).

import gleam/bit_array
import gleam/erlang/charlist.{type Charlist}
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
        attribute.src(data_uri(svg)),
        attribute.alt(page_label(index + 1)),
      ])
    }),
  )
}

/// Characters kept as they are besides letters, digits and `-._~`. They
/// include everything in a base64 `data:` URI, so a photo embedded in the
/// page stays findable as is (ADR 0039).
const unencoded = "/:;,=()!*'~?@$+"

/// Percent-encoded text, which gzip compresses well; base64 only for pages
/// that are not valid UTF-8.
fn data_uri(svg: BitArray) -> String {
  case bit_array.to_string(svg) {
    Ok(text) ->
      "data:image/svg+xml," <> quote(text, charlist.from_string(unencoded))
    Error(Nil) ->
      "data:image/svg+xml;base64," <> bit_array.base64_encode(svg, True)
  }
}

@external(erlang, "uri_string", "quote")
fn quote(text: String, safe: Charlist) -> String

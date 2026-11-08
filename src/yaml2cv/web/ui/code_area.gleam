//// Monospaced text editor field with line numbers
//// (`priv/static/css/components/code-area.css`, ADR 0021).

import gleam/int
import gleam/list
import gleam/string
import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html

/// A labelled textarea for source code with a line-number gutter. The label
/// is visually hidden but available to assistive technology. Lines do not
/// wrap, so every source line is one row next to its number; `editor.js`
/// keeps the gutter in sync while typing and scrolling.
pub fn view(
  id id: String,
  name name: String,
  label label: String,
  value value: String,
  attributes attributes: List(Attribute(message)),
) -> Element(message) {
  html.div([attribute.class("ui-code-area")], [
    html.label([attribute.for(id), attribute.class("ui-visually-hidden")], [
      html.text(label),
    ]),
    html.pre(
      [
        attribute.class("ui-code-area__gutter"),
        attribute.data("gutter-for", id),
        attribute.aria_hidden(True),
      ],
      [html.text(line_numbers(value))],
    ),
    html.textarea(
      [
        attribute.id(id),
        attribute.name(name),
        attribute.class("ui-code-area__input"),
        attribute.spellcheck(False),
        attribute.autocomplete("off"),
        attribute.attribute("autocapitalize", "off"),
        attribute.attribute("wrap", "off"),
        attribute.data("tab-indent", "2"),
        ..attributes
      ],
      value,
    ),
  ])
}

/// The gutter text for `source`: one number per line, newline-separated.
/// A trailing newline starts a further, empty line, as in the textarea.
pub fn line_numbers(source: String) -> String {
  let count =
    source
    |> string.replace("\r\n", "\n")
    |> string.split("\n")
    |> list.length
  int.range(from: 1, to: count + 1, with: [], run: fn(numbers, n) {
    [int.to_string(n), ..numbers]
  })
  |> list.reverse
  |> string.join("\n")
}

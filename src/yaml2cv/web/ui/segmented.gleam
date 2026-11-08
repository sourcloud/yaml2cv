//// Segmented control (`priv/static/css/components/segmented.css`).

import gleam/list
import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html

/// One choice of a segmented control.
pub type Option(message) {
  Option(label: String, pressed: Bool, attributes: List(Attribute(message)))
}

/// A group of toggle buttons of which one is pressed. Behaviour comes from
/// the options' attributes.
pub fn view(
  label label: String,
  options options: List(Option(message)),
) -> Element(message) {
  html.div(
    [
      attribute.class("ui-segmented"),
      attribute.role("group"),
      attribute.aria("label", label),
    ],
    list.map(options, fn(option) {
      html.button(
        [
          attribute.type_("button"),
          attribute.class("ui-segmented__option"),
          attribute.aria_pressed(case option.pressed {
            True -> "true"
            False -> "false"
          }),
          ..option.attributes
        ],
        [html.text(option.label)],
      )
    }),
  )
}

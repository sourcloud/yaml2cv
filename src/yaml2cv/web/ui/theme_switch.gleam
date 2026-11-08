//// Colour theme switch (`priv/static/css/components/theme-switch.css`,
//// behaviour in `priv/static/js/theme.js`, ADR 0012).

import gleam/list
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

/// A System / Light / Dark segmented control with the given labels. It
/// starts hidden and is revealed by `theme.js`, which also marks the active
/// choice.
pub fn view(
  label label: String,
  system system: String,
  light light: String,
  dark dark: String,
) -> Element(message) {
  html.div(
    [
      attribute.class("ui-theme-switch"),
      attribute.role("group"),
      attribute.aria("label", label),
      attribute.attribute("hidden", ""),
    ],
    list.map(
      [#("system", system), #("light", light), #("dark", dark)],
      fn(choice) {
        html.button(
          [
            attribute.type_("button"),
            attribute.class("ui-theme-switch__option"),
            attribute.data("theme-choice", choice.0),
            attribute.aria("pressed", "false"),
          ],
          [html.text(choice.1)],
        )
      },
    ),
  )
}

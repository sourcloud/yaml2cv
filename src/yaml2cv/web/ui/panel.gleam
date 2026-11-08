//// Panel component (`priv/static/css/components/panel.css`).

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

/// A titled surface with optional header actions.
pub fn view(
  title title: String,
  actions actions: List(Element(message)),
  body body: List(Element(message)),
) -> Element(message) {
  html.section([attribute.class("ui-panel")], [
    html.header([attribute.class("ui-panel__header")], [
      html.h2([attribute.class("ui-panel__title")], [html.text(title)]),
      html.div([attribute.class("ui-panel__actions")], actions),
    ]),
    html.div([attribute.class("ui-panel__body")], body),
  ])
}

//// Request-in-flight indicator (`priv/static/css/components/indicator.css`).
//// Point an element's `hx-indicator` at its id to show it during requests.

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

/// A muted label that becomes visible while a request is running.
pub fn view(id id: String, label label: String) -> Element(message) {
  html.span(
    [
      attribute.id(id),
      attribute.class("ui-indicator"),
      attribute.aria("live", "polite"),
    ],
    [html.text(label)],
  )
}

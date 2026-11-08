//// Alert component (`priv/static/css/components/alert.css`).

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub type Tone {
  Info
  Success
  Danger
}

/// A status message with a title and optional body content.
pub fn view(
  tone: Tone,
  title: String,
  body: List(Element(message)),
) -> Element(message) {
  let #(modifier, role) = case tone {
    Info -> #("ui-alert--info", "status")
    Success -> #("ui-alert--success", "status")
    Danger -> #("ui-alert--danger", "alert")
  }
  html.div([attribute.class("ui-alert " <> modifier), attribute.role(role)], [
    html.p([attribute.class("ui-alert__title")], [html.text(title)]),
    case body {
      [] -> element.none()
      _ -> html.div([attribute.class("ui-alert__body")], body)
    },
  ])
}

//// Button component (`priv/static/css/components/button.css`).

import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html

pub type Variant {
  Primary
  Secondary
}

/// A button; pass `type`, `form` and similar via `attributes`.
pub fn view(
  variant: Variant,
  attributes: List(Attribute(message)),
  label: String,
) -> Element(message) {
  let modifier = case variant {
    Primary -> "ui-button--primary"
    Secondary -> "ui-button--secondary"
  }
  html.button([attribute.class("ui-button " <> modifier), ..attributes], [
    html.text(label),
  ])
}

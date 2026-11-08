//// Monospaced text editor field (`priv/static/css/components/code-area.css`).

import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html

/// A labelled textarea for source code. The label is visually hidden but
/// available to assistive technology.
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
    html.textarea(
      [
        attribute.id(id),
        attribute.name(name),
        attribute.class("ui-code-area__input"),
        attribute.spellcheck(False),
        attribute.autocomplete("off"),
        attribute.attribute("autocapitalize", "off"),
        attribute.data("tab-indent", "2"),
        ..attributes
      ],
      value,
    ),
  ])
}

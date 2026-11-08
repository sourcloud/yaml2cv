//// A building block of the visual editor
//// (`priv/static/css/components/block.css`, ADR 0024).

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

/// A titled group of fields with optional actions (move, remove) next to
/// the title. Blocks nest: a section block holds entry blocks.
pub fn view(
  title title: String,
  actions actions: List(Element(message)),
  body body: List(Element(message)),
) -> Element(message) {
  html.fieldset([attribute.class("ui-block")], [
    html.legend([attribute.class("ui-block__title")], [html.text(title)]),
    case actions {
      [] -> element.none()
      actions -> html.div([attribute.class("ui-block__actions")], actions)
    },
    html.div([attribute.class("ui-block__body")], body),
  ])
}

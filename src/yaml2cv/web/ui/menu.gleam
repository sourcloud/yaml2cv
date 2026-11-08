//// Menu button component (`priv/static/css/components/menu.css`).

import gleam/list
import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html

/// One entry of a menu; pass the data attributes that make it act via
/// `attributes`.
pub type Item(message) {
  Item(label: String, attributes: List(Attribute(message)))
}

/// Which edge of the button the list lines up with: `Start` opens it towards
/// the inline end, for buttons at the start of a row; `End` the other way.
pub type Align {
  Start
  End
}

/// A button labelled `label` that opens a list of `items` below it, following
/// the WAI-ARIA menu button pattern. `editor.js` opens and closes the list
/// and moves focus between the items with the arrow keys; an item's click
/// closes the list.
pub fn view(
  id id: String,
  label label: String,
  align align: Align,
  items items: List(Item(message)),
) -> Element(message) {
  let list_id = id <> "-menu"
  let list_class = case align {
    Start -> "ui-menu__list ui-menu__list--start"
    End -> "ui-menu__list"
  }
  html.div([attribute.class("ui-menu"), attribute.data("menu", "")], [
    html.button(
      [
        attribute.id(id),
        attribute.class("ui-button ui-button--secondary ui-menu__trigger"),
        attribute.type_("button"),
        attribute.aria_haspopup("menu"),
        attribute.aria_expanded(False),
        attribute.aria_controls(list_id),
        attribute.data("menu-trigger", ""),
      ],
      [html.text(label)],
    ),
    html.div(
      [
        attribute.id(list_id),
        attribute.class(list_class),
        attribute.role("menu"),
        attribute.aria_labelledby(id),
        attribute.attribute("hidden", ""),
      ],
      list.map(items, fn(item) {
        html.button(
          [
            attribute.class("ui-menu__item"),
            attribute.type_("button"),
            attribute.role("menuitem"),
            attribute.attribute("tabindex", "-1"),
            ..item.attributes
          ],
          [html.text(item.label)],
        )
      }),
    ),
  ])
}

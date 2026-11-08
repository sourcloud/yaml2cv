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

/// A button labelled `label` that opens a list of `items` below it, following
/// the WAI-ARIA menu button pattern. `editor.js` opens and closes the list
/// and moves focus between the items with the arrow keys; an item's click
/// closes the list.
pub fn view(
  id id: String,
  label label: String,
  items items: List(Item(message)),
) -> Element(message) {
  let list_id = id <> "-menu"
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
        attribute.class("ui-menu__list"),
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

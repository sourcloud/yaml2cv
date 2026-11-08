//// Modal dialog component (`priv/static/css/components/dialog.css`).

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

/// A modal `<dialog>` with a title and a Close button. Open it with a button
/// carrying `data-dialog-open="<id>"` (see `editor.js`). The Close button
/// submits a `method="dialog"` form, so closing needs no script.
pub fn view(
  id id: String,
  title title: String,
  body body: List(Element(message)),
) -> Element(message) {
  let title_id = id <> "-title"
  html.dialog(
    [
      attribute.id(id),
      attribute.class("ui-dialog"),
      attribute.aria_labelledby(title_id),
      attribute.attribute("closedby", "any"),
    ],
    [
      html.header([attribute.class("ui-dialog__header")], [
        html.h2([attribute.id(title_id), attribute.class("ui-dialog__title")], [
          html.text(title),
        ]),
        html.form([attribute.method("dialog")], [
          html.button([attribute.class("ui-button ui-button--secondary")], [
            html.text("Close"),
          ]),
        ]),
      ]),
      html.div([attribute.class("ui-dialog__body")], body),
    ],
  )
}

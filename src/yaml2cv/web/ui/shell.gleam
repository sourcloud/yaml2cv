//// Application shell: document head and page chrome
//// (`priv/static/css/components/shell.css`).

import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

/// Path of the vendored htmx build.
pub const htmx_path = "/static/vendor/htmx-2.0.4.min.js"

/// A full HTML document with header and main content area.
pub fn view(
  title title: String,
  actions actions: List(Element(message)),
  content content: List(Element(message)),
) -> Element(message) {
  html.html([attribute.lang("en")], [
    html.head([], [
      html.meta([attribute.charset("utf-8")]),
      html.meta([
        attribute.name("viewport"),
        attribute.content("width=device-width, initial-scale=1"),
      ]),
      // Keeps htmx from injecting inline styles, which the CSP forbids.
      html.meta([
        attribute.name("htmx-config"),
        attribute.content("{\"includeIndicatorStyles\":false}"),
      ]),
      html.title([], title),
      html.link([
        attribute.rel("stylesheet"),
        attribute.href("/static/css/app.css"),
      ]),
      html.script(
        [attribute.src(htmx_path), attribute.attribute("defer", "")],
        "",
      ),
      html.script(
        [
          attribute.src("/static/js/editor.js"),
          attribute.attribute("defer", ""),
        ],
        "",
      ),
    ]),
    html.body([attribute.class("ui-shell")], [
      html.header([attribute.class("ui-shell__header")], [
        html.a([attribute.class("ui-shell__brand"), attribute.href("/")], [
          html.text(title),
        ]),
        html.div([attribute.class("ui-shell__actions")], actions),
      ]),
      html.main([attribute.class("ui-shell__main")], content),
    ]),
  ])
}

//// Application shell: document head and page chrome
//// (`priv/static/css/components/shell.css`).

import gleam/json
import gleam/option.{type Option}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import yaml2cv/web/i18n.{type Locale}
import yaml2cv/web/ui/language_switch
import yaml2cv/web/ui/theme_switch

/// Path of the vendored htmx build.
pub const htmx_path = "/static/vendor/htmx-2.0.4.min.js"

/// A full HTML document in `locale` with header and main content area.
/// The language switch submits `language_form` when given (ADR 0025).
pub fn view(
  locale locale: Locale,
  language_form language_form: Option(String),
  title title: String,
  actions actions: List(Element(message)),
  content content: List(Element(message)),
) -> Element(message) {
  let texts = i18n.texts(locale).ui
  let code = i18n.code(locale)
  html.html([attribute.lang(code)], [
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
      // Not deferred: applies the stored colour theme before the first paint.
      html.script([attribute.src("/static/js/theme.js")], ""),
      // Not deferred: loads the stored language before the page is shown.
      html.script([attribute.src("/static/js/language.js")], ""),
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
    html.body(
      [
        attribute.class("ui-shell"),
        // Every htmx request answers in the page's language.
        attribute.attribute(
          "hx-headers",
          json.to_string(json.object([#(i18n.header, json.string(code))])),
        ),
      ],
      [
        html.header([attribute.class("ui-shell__header")], [
          html.a([attribute.class("ui-shell__brand"), attribute.href("/")], [
            html.text(title),
          ]),
          html.div([attribute.class("ui-shell__actions")], [
            language_switch.view(
              label: texts.language_label,
              current: locale,
              form: language_form,
            ),
            theme_switch.view(
              label: texts.theme_label,
              system: texts.theme_system,
              light: texts.theme_light,
              dark: texts.theme_dark,
            ),
            ..actions
          ]),
        ]),
        html.main([attribute.class("ui-shell__main")], content),
      ],
    ),
  ])
}

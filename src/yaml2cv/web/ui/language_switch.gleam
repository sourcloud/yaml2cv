//// UI language switch (styled as `ui-segmented`, behaviour without script;
//// `priv/static/js/language.js` remembers the choice, ADR 0025).

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import yaml2cv/web/i18n.{type Locale}

/// One submit button per locale that posts `lang` to `/`, the current one
/// pressed. With `form`, the buttons submit that form, so its fields (the
/// editor's YAML) come along; otherwise they sit in a form of their own.
pub fn view(
  label label: String,
  current current: Locale,
  form form: Option(String),
) -> Element(message) {
  let buttons =
    list.map(i18n.all, fn(locale) {
      let code = i18n.code(locale)
      html.button(
        [
          attribute.type_("submit"),
          attribute.class("ui-segmented__option"),
          attribute.name("lang"),
          attribute.value(code),
          attribute.attribute("formmethod", "post"),
          attribute.attribute("formaction", "/"),
          attribute.lang(code),
          attribute.aria_label(i18n.endonym(locale)),
          attribute.title(i18n.endonym(locale)),
          attribute.aria_pressed(case locale == current {
            True -> "true"
            False -> "false"
          }),
          attribute.data("language-choice", code),
          ..case form {
            Some(form) -> [attribute.form(form)]
            None -> []
          }
        ],
        [html.text(string.uppercase(code))],
      )
    })
  let group =
    html.div(
      [
        attribute.class("ui-segmented ui-language-switch"),
        attribute.role("group"),
        attribute.aria("label", label),
      ],
      buttons,
    )
  case form {
    Some(_) -> group
    None ->
      html.form(
        [
          attribute.class("ui-language-switch__form"),
          attribute.method("post"),
          attribute.action("/"),
        ],
        [group],
      )
  }
}

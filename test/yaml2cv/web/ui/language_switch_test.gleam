import birdie
import gleam/option.{None, Some}
import gleam/string
import lustre/element
import yaml2cv/web/i18n.{De, En}
import yaml2cv/web/ui/language_switch

pub fn language_switch_for_a_form_test() {
  language_switch.view(
    label: "Language",
    current: En,
    form: Some("editor-form"),
  )
  |> element.to_string
  |> birdie.snap(title: "ui language switch")
}

pub fn language_switch_with_its_own_form_test() {
  let html =
    language_switch.view(label: "Sprache", current: De, form: None)
    |> element.to_string
  assert string.starts_with(html, "<form")
  assert string.contains(html, "action=\"/\"")
  assert !string.contains(html, "form=\"")
  assert string.contains(html, "aria-pressed=\"true\"")
}

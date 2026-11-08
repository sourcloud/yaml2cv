import birdie
import gleam/option.{None}
import gleam/string
import lustre/element
import lustre/element/html
import yaml2cv/web/i18n.{De, En}
import yaml2cv/web/ui/shell

pub fn document_shell_test() {
  shell.view(
    locale: En,
    language_form: None,
    title: "yaml2cv",
    actions: [html.text("actions")],
    content: [html.text("content")],
  )
  |> element.to_document_string
  |> birdie.snap(title: "ui shell document")
}

pub fn german_shell_test() {
  let html =
    shell.view(
      locale: De,
      language_form: None,
      title: "yaml2cv",
      actions: [],
      content: [],
    )
    |> element.to_document_string
  assert string.contains(html, "<html lang=\"de\">")
  assert string.contains(html, "x-yaml2cv-lang&quot;:&quot;de")
    || string.contains(html, "{\"x-yaml2cv-lang\":\"de\"}")
  assert string.contains(html, "aria-label=\"Farbschema\"")
  assert string.contains(html, "aria-label=\"Sprache\"")
}

import birdie
import gleam/option.{None}
import gleam/string
import lustre/element
import lustre/element/html
import yaml2cv/build.{Build, Clean, Modified, Unknown}
import yaml2cv/web/i18n.{De, En}
import yaml2cv/web/ui/shell

const hash = "37e695e1c0ffee00000000000000000000000000"

const release = Build(version: "1.2.3", revision: Clean(hash))

pub fn document_shell_test() {
  shell.view(
    locale: En,
    language_form: None,
    build: release,
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
      build: release,
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

fn footer(locale: i18n.Locale, revision: build.Revision) -> String {
  shell.view(
    locale:,
    language_form: None,
    build: Build(version: "1.2.3", revision:),
    title: "yaml2cv",
    actions: [],
    content: [],
  )
  |> element.to_document_string
}

pub fn footer_links_to_commit_and_source_test() {
  let html = footer(En, Clean(hash))
  assert string.contains(html, "<footer class=\"ui-shell__footer\">")
  assert string.contains(html, "yaml2cv 1.2.3")
  assert string.contains(
    html,
    "href=\"https://github.com/sourcloud/yaml2cv/commit/" <> hash <> "\"",
  )
  assert string.contains(html, ">37e695e</a>")
  assert string.contains(
    html,
    "href=\"https://github.com/sourcloud/yaml2cv\">Source code on GitHub</a>",
  )
  assert !string.contains(html, "modified")
}

pub fn footer_marks_modified_build_test() {
  let html = footer(En, Modified(hash))
  assert string.contains(html, ">37e695e</a>")
  assert string.contains(html, "modified")
}

pub fn footer_without_revision_test() {
  let html = footer(En, Unknown)
  assert string.contains(html, "revision unknown")
  assert !string.contains(html, "/commit/")
}

pub fn german_footer_test() {
  let html = footer(De, Modified(hash))
  assert string.contains(html, "Quellcode auf GitHub")
  assert string.contains(html, "verändert")
  assert string.contains(footer(De, Unknown), "Revision unbekannt")
}

//// The licenses page: yaml2cv's own license and the third-party components
//// with their license texts (ADR 0032). Served as a full page, or as a
//// fragment for the dialog opened from the footer.

import gleam/list
import gleam/option.{None}
import gleam/string
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import wisp.{type Response}
import yaml2cv/build.{type Build}
import yaml2cv/notices.{type Component}
import yaml2cv/web/i18n.{type Locale}
import yaml2cv/web/ui/shell

/// The licenses as a full HTML page.
pub fn page(
  locale: Locale,
  build: Build,
  components: List(Component),
) -> Response {
  shell.view(
    locale:,
    language_form: None,
    build:,
    title: "yaml2cv – " <> i18n.texts(locale).licenses.title,
    actions: [],
    content: [
      html.article([attribute.class("licenses")], [
        html.h1([attribute.class("licenses__title")], [
          html.text(i18n.texts(locale).licenses.title),
        ]),
        ..view(locale, components)
      ]),
    ],
  )
  |> element.to_document_string
  |> wisp.html_response(200)
}

/// The licenses without page chrome, for the footer dialog.
pub fn fragment(locale: Locale, components: List(Component)) -> Response {
  view(locale, components)
  |> element.fragment
  |> element.to_string
  |> wisp.html_response(200)
}

/// The own license and one collapsible entry per component.
pub fn view(locale: Locale, components: List(Component)) -> List(Element(a)) {
  let texts = i18n.texts(locale).licenses
  let own =
    html.p([], [
      html.text(texts.own_license <> " "),
      html.a([attribute.href(build.repository <> "/blob/master/LICENSE")], [
        html.text(texts.read_license),
      ]),
    ])
  case components {
    [] -> [own, html.p([], [html.text(texts.unavailable)])]
    _ -> [
      own,
      html.p([], [html.text(texts.intro)]),
      html.div(
        [attribute.class("licenses__list")],
        list.map(components, component(_, texts.see_license_file)),
      ),
    ]
  }
}

fn component(component: Component, see_license_file: String) -> Element(a) {
  let licenses = case component.licenses {
    [] -> see_license_file
    licenses -> string.join(licenses, ", ")
  }
  html.details([attribute.class("licenses__component")], [
    html.summary([], [
      html.strong([], [html.text(component.name)]),
      html.text(" " <> component.version <> " · " <> licenses),
    ]),
    ..list.flat_map(component.files, fn(file) {
      [
        html.h3([], [html.text(file.name)]),
        html.pre([attribute.class("licenses__text")], [html.text(file.text)]),
      ]
    })
  ])
}

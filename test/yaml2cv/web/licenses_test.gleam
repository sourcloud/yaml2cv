import birdie
import gleam/string
import lustre/element
import lustre/element/html
import yaml2cv/notices.{Component, LicenseFile, Source}
import yaml2cv/web/i18n.{De, En}
import yaml2cv/web/licenses

const components = [
  Component(
    name: "Inter",
    version: "4.1",
    licenses: ["OFL-1.1"],
    files: [LicenseFile(name: "OFL.txt", text: "Copyright <Inter>\n")],
    sources: [],
  ),
  Component(
    name: "Typst",
    version: "0.15.1",
    licenses: [],
    files: [
      LicenseFile(name: "LICENSE", text: "Apache"),
      LicenseFile(name: "NOTICE", text: "Notice"),
    ],
    sources: [
      Source(
        description: "New Computer Modern 8.1.1",
        url: "https://example.org/newcm.txz",
      ),
    ],
  ),
]

fn render(locale, components) -> String {
  licenses.view(locale, components)
  |> html.div([], _)
  |> element.to_string
}

pub fn lists_components_with_license_texts_test() {
  render(En, components)
  |> birdie.snap(title: "licenses view")
}

pub fn german_view_test() {
  let html = render(De, components)
  assert string.contains(html, "siehe Lizenzdatei")
}

pub fn explains_missing_notices_test() {
  let html = render(En, [])
  assert string.contains(html, "generated when the container image is built")
  assert !string.contains(html, "<details")
}

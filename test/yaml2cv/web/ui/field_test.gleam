import birdie
import gleam/string
import lustre/element
import yaml2cv/web/ui/field

pub fn text_field_test() {
  field.text(
    name: "person.name",
    label: "Name",
    value: "Jane \"JR\" Roe",
    requirement: field.Required(" (required)"),
  )
  |> element.to_string
  |> birdie.snap(title: "ui field text")
}

pub fn textarea_field_test() {
  field.textarea(
    name: "sections.0.text",
    label: "Text",
    value: "a\n</textarea>",
    requirement: field.Optional,
  )
  |> element.to_string
  |> birdie.snap(title: "ui field textarea")
}

pub fn select_field_test() {
  field.select(
    name: "style.theme",
    label: "Theme",
    options: [#("", "classic"), #("minimal", "minimal")],
    value: "minimal",
  )
  |> element.to_string
  |> birdie.snap(title: "ui field select")
}

pub fn text_field_with_info_test() {
  field.text_with_info(
    name: "language",
    label: "Language",
    value: "de",
    requirement: field.Optional,
    info: field.Info(
      button: "About language",
      close: "Close",
      body: "A two-letter code such as en or de.",
    ),
  )
  |> element.to_string
  |> birdie.snap(title: "ui field text with info")
}

pub fn info_button_sits_outside_the_label_test() {
  // A button inside the <label> would become its control and steal clicks
  // on the label text from the input.
  let html =
    field.text_with_info(
      name: "language",
      label: "Language",
      value: "",
      requirement: field.Optional,
      info: field.Info(button: "About", close: "Close", body: "Text"),
    )
    |> element.to_string
  let assert [label, _] = string.split(html, "</label>")
  assert !string.contains(label, "<button")
  assert string.contains(html, "for=\"field-language\"")
  assert string.contains(html, "id=\"field-language\"")
  assert string.contains(html, "popovertarget=\"field-language-info\"")
  assert string.contains(html, "id=\"field-language-info\" popover")
}

fn photo(value: String) -> String {
  field.photo(
    name: "person.photo",
    label: "Photo",
    value:,
    labels: field.PhotoLabels(
      choose: "Choose",
      change: "Change",
      remove: "Remove",
      failed: "Failed",
    ),
  )
  |> element.to_string
}

pub fn photo_field_without_photo_offers_choose_only_test() {
  let html = photo("")
  assert string.contains(html, ">Choose</button>")
  assert string.contains(html, "data-change-label=\"Change\"")
  assert string.contains(html, "data-photo-remove hidden")
}

pub fn photo_field_with_photo_offers_change_and_remove_test() {
  let html = photo("data:image/png;base64,iVBORw0KGgo=")
  assert string.contains(html, ">Change</button>")
  assert string.contains(html, "data-choose-label=\"Choose\"")
  assert !string.contains(html, "data-photo-remove hidden")
  assert string.contains(html, ">Remove</button>")
}

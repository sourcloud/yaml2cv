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
    options: [#("", "Default (classic)"), #("minimal", "minimal")],
    value: "minimal",
  )
  |> element.to_string
  |> birdie.snap(title: "ui field select")
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

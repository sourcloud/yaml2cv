import birdie
import lustre/element
import yaml2cv/web/ui/field

pub fn text_field_test() {
  field.text(
    name: "person.name",
    label: "Name",
    value: "Jane \"JR\" Roe",
    requirement: field.Required,
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

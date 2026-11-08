import birdie
import lustre/attribute
import lustre/element
import yaml2cv/web/ui/code_area

pub fn code_area_test() {
  code_area.view(
    id: "cv",
    name: "yaml",
    label: "CV (YAML)",
    value: "person:\n  name: </textarea>",
    attributes: [attribute.attribute("hx-post", "/x")],
  )
  |> element.to_string
  |> birdie.snap(title: "ui code area")
}

pub fn numbers_every_line_including_a_trailing_empty_one_test() {
  assert code_area.line_numbers("a\nb\n") == "1\n2\n3"
  assert code_area.line_numbers("") == "1"
  assert code_area.line_numbers("a\r\nb") == "1\n2"
}

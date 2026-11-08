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

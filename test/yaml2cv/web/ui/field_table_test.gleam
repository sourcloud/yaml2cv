import birdie
import lustre/element
import lustre/element/html
import yaml2cv/web/ui/field_table.{Row}

pub fn field_table_test() {
  field_table.view(
    key_header: "Key",
    requirement_header: "Required",
    description_header: "Description",
    rows: [
      Row(key: "name", requirement: "required", description: [
        html.text("Your <full> name."),
      ]),
      Row(key: "title", requirement: "optional", description: []),
    ],
  )
  |> element.to_string
  |> birdie.snap(title: "ui field table")
}

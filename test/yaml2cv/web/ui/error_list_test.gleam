import birdie
import gleam/option.{None, Some}
import lustre/element
import yaml2cv/web/ui/error_list.{Item, Target}

pub fn lists_errors_with_location_test() {
  error_list.view(
    document_label: "document",
    jump_label: "Show in editor",
    errors: [
      Item(location: "person.name", message: "is required", target: None),
      Item(location: "", message: "expected a mapping", target: None),
      Item(location: "<script>", message: "is <escaped>", target: None),
    ],
  )
  |> element.to_string
  |> birdie.snap(title: "ui error list")
}

pub fn links_errors_to_editor_positions_test() {
  error_list.view(
    document_label: "document",
    jump_label: "Show in editor",
    errors: [
      Item(
        location: "line 2, column 5",
        message: "Unfinished flow collection",
        target: Some(Target(field: "cv", line: 2, column: 5)),
      ),
    ],
  )
  |> element.to_string
  |> birdie.snap(title: "ui error list with jump target")
}

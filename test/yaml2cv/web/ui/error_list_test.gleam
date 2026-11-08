import birdie
import lustre/element
import yaml2cv/web/ui/error_list

pub fn lists_errors_with_location_test() {
  error_list.view([
    #("person.name", "is required"),
    #("", "expected a mapping"),
    #("<script>", "is <escaped>"),
  ])
  |> element.to_string
  |> birdie.snap(title: "ui error list")
}

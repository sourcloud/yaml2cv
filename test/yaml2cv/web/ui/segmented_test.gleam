import birdie
import lustre/attribute
import lustre/element
import yaml2cv/web/ui/segmented.{Option}

pub fn segmented_test() {
  segmented.view(label: "Edit mode", options: [
    Option("YAML", True, [attribute.data("mode-switch", "yaml")]),
    Option("Visual", False, [attribute.data("mode-switch", "visual")]),
  ])
  |> element.to_string
  |> birdie.snap(title: "ui segmented")
}

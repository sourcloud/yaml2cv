import birdie
import lustre/element
import yaml2cv/web/ui/indicator

pub fn indicator_test() {
  indicator.view(id: "preview-indicator", label: "Rendering…")
  |> element.to_string
  |> birdie.snap(title: "ui indicator")
}

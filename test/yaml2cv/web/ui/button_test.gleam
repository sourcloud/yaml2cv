import birdie
import lustre/attribute
import lustre/element
import yaml2cv/web/ui/button

pub fn primary_button_test() {
  button.view(button.Primary, [attribute.type_("submit")], "Download PDF")
  |> element.to_string
  |> birdie.snap(title: "ui button primary")
}

pub fn secondary_button_test() {
  button.view(button.Secondary, [], "Reset")
  |> element.to_string
  |> birdie.snap(title: "ui button secondary")
}

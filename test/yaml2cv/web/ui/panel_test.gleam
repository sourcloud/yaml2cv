import birdie
import lustre/element
import lustre/element/html
import yaml2cv/web/ui/panel

pub fn panel_with_actions_test() {
  panel.view(title: "Preview", actions: [html.text("action")], body: [
    html.text("body"),
  ])
  |> element.to_string
  |> birdie.snap(title: "ui panel")
}

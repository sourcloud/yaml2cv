import birdie
import lustre/element
import lustre/element/html
import yaml2cv/web/ui/dialog

pub fn dialog_test() {
  dialog.view(id: "help", title: "Help <me>", close: "Close", body: [
    html.text("body"),
  ])
  |> element.to_string
  |> birdie.snap(title: "ui dialog")
}

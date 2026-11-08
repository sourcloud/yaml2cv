import birdie
import lustre/element
import lustre/element/html
import yaml2cv/web/ui/shell

pub fn document_shell_test() {
  shell.view(title: "yaml2cv", actions: [html.text("actions")], content: [
    html.text("content"),
  ])
  |> element.to_document_string
  |> birdie.snap(title: "ui shell document")
}

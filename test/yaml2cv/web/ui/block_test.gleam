import birdie
import lustre/element
import lustre/element/html
import yaml2cv/web/ui/block
import yaml2cv/web/ui/button

pub fn block_test() {
  block.view(
    title: "Entry",
    actions: [button.view(button.Quiet, [], "Remove")],
    body: [html.text("fields")],
  )
  |> element.to_string
  |> birdie.snap(title: "ui block")
}

pub fn block_without_actions_test() {
  block.view(title: "Person", actions: [], body: [])
  |> element.to_string
  |> birdie.snap(title: "ui block without actions")
}

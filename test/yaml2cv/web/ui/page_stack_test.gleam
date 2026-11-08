import birdie
import gleam/int
import lustre/element
import yaml2cv/web/ui/page_stack

pub fn shows_svg_pages_as_data_uris_test() {
  page_stack.view([<<1, 2, 3>>, <<4, 5>>], page_label)
  |> element.to_string
  |> birdie.snap(title: "ui page stack")
}

pub fn empty_page_stack_test() {
  page_stack.view([], page_label)
  |> element.to_string
  |> birdie.snap(title: "ui page stack empty")
}

fn page_label(number: Int) -> String {
  "Page " <> int.to_string(number)
}

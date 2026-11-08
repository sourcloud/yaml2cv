import birdie
import gleam/string
import lustre/attribute
import lustre/element
import yaml2cv/web/ui/menu

pub fn menu_test() {
  menu.view(id: "file", label: "File <x>", align: menu.End, items: [
    menu.Item("Copy", [attribute.data("copy-from", "cv")]),
    menu.Item("Import…", []),
  ])
  |> element.to_string
  |> birdie.snap(title: "ui menu")
}

pub fn start_aligned_menu_test() {
  let html =
    menu.view(id: "add", label: "Add", align: menu.Start, items: [])
    |> element.to_string
  assert string.contains(html, "class=\"ui-menu__list ui-menu__list--start\"")
}

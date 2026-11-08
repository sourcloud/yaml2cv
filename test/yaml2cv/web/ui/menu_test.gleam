import birdie
import lustre/attribute
import lustre/element
import yaml2cv/web/ui/menu

pub fn menu_test() {
  menu.view(id: "file", label: "File <x>", items: [
    menu.Item("Copy", [attribute.data("copy-from", "cv")]),
    menu.Item("Import…", []),
  ])
  |> element.to_string
  |> birdie.snap(title: "ui menu")
}

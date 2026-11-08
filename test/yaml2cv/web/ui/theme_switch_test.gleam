import birdie
import lustre/element
import yaml2cv/web/ui/theme_switch

pub fn theme_switch_test() {
  theme_switch.view()
  |> element.to_string
  |> birdie.snap(title: "ui theme switch")
}

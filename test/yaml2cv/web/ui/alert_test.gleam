import birdie
import lustre/element
import lustre/element/html
import yaml2cv/web/ui/alert

pub fn success_alert_test() {
  alert.view(alert.Success, "Valid CV", [])
  |> element.to_string
  |> birdie.snap(title: "ui alert success")
}

pub fn danger_alert_with_body_test() {
  alert.view(alert.Danger, "2 problems", [html.text("Fix them.")])
  |> element.to_string
  |> birdie.snap(title: "ui alert danger with body")
}

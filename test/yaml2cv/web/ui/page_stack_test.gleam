import birdie
import gleam/int
import gleam/string
import lustre/element
import yaml2cv/web/ui/page_stack

pub fn shows_svg_pages_as_data_uris_test() {
  page_stack.view([<<1, 2, 3>>, <<4, 5>>], page_label)
  |> element.to_string
  |> birdie.snap(title: "ui page stack")
}

pub fn embeds_svg_as_percent_encoded_text_test() {
  let svg = <<
    "<svg a=\"x\"><image href=\"data:image/png;base64,ab+/=\"/>ä #%\n</svg>":utf8,
  >>
  let html = page_stack.view([svg], page_label) |> element.to_string
  assert string.contains(
    html,
    "src=\"data:image/svg+xml,%3Csvg%20a=%22x%22%3E%3Cimage%20href=%22data:image/png;base64,ab+/=%22/%3E%C3%A4%20%23%25%0A%3C/svg%3E\"",
  )
}

pub fn falls_back_to_base64_for_invalid_utf8_test() {
  let html = page_stack.view([<<0xFF, 0xFE>>], page_label) |> element.to_string
  assert string.contains(html, "src=\"data:image/svg+xml;base64,//4=\"")
}

pub fn empty_page_stack_test() {
  page_stack.view([], page_label)
  |> element.to_string
  |> birdie.snap(title: "ui page stack empty")
}

fn page_label(number: Int) -> String {
  "Page " <> int.to_string(number)
}

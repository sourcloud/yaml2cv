import birdie
import gleam/list
import gleam/string
import lustre/element
import simplifile
import yaml2cv/cv/draft.{
  Contact, Draft, Entries, Entry, Link, Section, Skill, Skills, Text,
}
import yaml2cv/web/visual
import yaml2cv/web/visual_form

fn sample() -> draft.Draft {
  Draft(
    style: draft.Style(theme: "minimal", color: "", paper: ""),
    person: draft.Person(name: "Jane <Roe>", title: "", address: ""),
    contact: Contact(..draft.empty.contact, links: [Link("GitHub", "https://x")]),
    sections: [
      Section(
        "Work",
        Entries([
          Entry(..draft.blank_entry, title: "One", bullets: ["x", "y"]),
          Entry(..draft.blank_entry, title: "Two"),
        ]),
      ),
      Section("Langs", Skills([Skill("English", "")])),
      Section("About", Text("Hi")),
    ],
  )
}

pub fn renders_blocks_test() {
  sample()
  |> visual.view
  |> element.to_string
  |> birdie.snap(title: "visual editor blocks")
}

pub fn renders_a_field_for_every_draft_value_test() {
  let assert Ok(yaml) = simplifile.read("priv/examples/example.yaml")
  let assert Ok(cv) = draft.from_yaml(yaml)
  let html = element.to_string(visual.view(cv))
  list.each(visual_form.fields(cv), fn(field) {
    assert string.contains(html, "name=\"" <> field.0 <> "\"") as field.0
  })
}

pub fn offers_only_possible_moves_test() {
  let html = element.to_string(visual.view(sample()))
  assert !string.contains(html, "value=\"up:sections.0\"")
  assert string.contains(html, "value=\"down:sections.0\"")
  assert string.contains(html, "value=\"up:sections.2\"")
  assert !string.contains(html, "value=\"down:sections.2\"")
  assert string.contains(
    html,
    "value=\"remove:sections.0.entries.0.bullets.1\"",
  )
  assert string.contains(html, "value=\"add-section:text\"")
}

pub fn sync_carries_escaped_yaml_out_of_band_test() {
  let html = element.to_string(visual.sync("name: </textarea>\n"))
  assert string.contains(html, "hx-swap-oob=\"true\"")
  assert string.contains(html, "id=\"yaml-sync\"")
  assert string.contains(html, "name: &lt;/textarea&gt;")
}

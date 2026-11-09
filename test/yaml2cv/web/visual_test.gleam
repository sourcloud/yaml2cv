import birdie
import gleam/list
import gleam/string
import lustre/element
import simplifile
import yaml2cv/cv/draft.{
  Contact, Draft, Entries, Entry, Link, Section, Skill, Skills, Text,
}
import yaml2cv/web/i18n
import yaml2cv/web/visual
import yaml2cv/web/visual_form

const en = i18n.En

fn sample() -> draft.Draft {
  Draft(
    language: "de",
    style: draft.Style(theme: "minimal", color: "", paper: "", photo_shape: ""),
    person: draft.Person(name: "Jane <Roe>", title: "", address: "", photo: ""),
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
  |> visual.view(i18n.texts(en))
  |> element.to_string
  |> birdie.snap(title: "visual editor blocks")
}

pub fn renders_german_blocks_test() {
  sample()
  |> visual.view(i18n.texts(i18n.De))
  |> element.to_string
  |> birdie.snap(title: "visual editor blocks de")
}

pub fn renders_a_field_for_every_draft_value_test() {
  let assert Ok(yaml) = simplifile.read("priv/examples/example.yaml")
  let assert Ok(cv) = draft.from_yaml(yaml)
  let html = element.to_string(visual.view(cv, i18n.texts(en)))
  list.each(visual_form.fields(cv), fn(field) {
    assert string.contains(html, "name=\"" <> field.0 <> "\"") as field.0
  })
}

pub fn places_the_photo_shape_next_to_the_photo_test() {
  let html = element.to_string(visual.view(sample(), i18n.texts(en)))
  let assert [_, after_person] = string.split(html, "name=\"person.photo\"")
  let assert [person_rest, _] =
    string.split(after_person, "name=\"contact.email\"")
  assert string.contains(person_rest, "name=\"style.photo_shape\"")
}

pub fn offers_adding_sections_from_a_menu_test() {
  let html = element.to_string(visual.view(sample(), i18n.texts(en)))
  assert string.contains(
    html,
    "data-menu-trigger id=\"add-section\" type=\"button\">Add section</button>",
  )
  assert string.contains(html, "ui-menu__list ui-menu__list--start")
  assert string.contains(
    html,
    "role=\"menuitem\" tabindex=\"-1\" type=\"button\" value=\"add-section:skills\">Skills</button>",
  )
}

pub fn offers_only_possible_moves_test() {
  let html = element.to_string(visual.view(sample(), i18n.texts(en)))
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

pub fn always_shows_both_arrows_test() {
  let html = element.to_string(visual.view(sample(), i18n.texts(i18n.En)))
  // Every item has a move group with two arrows; impossible moves are
  // disabled placeholders.
  let groups = string.split(html, "visual-editor__move") |> list.length
  let removes = string.split(html, "value=\"remove:") |> list.length
  assert groups == removes
  assert string.contains(
    html,
    "aria-hidden=\"true\" class=\"ui-button ui-button--quiet\" disabled",
  )
}

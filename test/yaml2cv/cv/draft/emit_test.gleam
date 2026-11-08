import birdie
import gleam/bit_array
import gleam/list
import gleam/option
import simplifile
import yaml2cv/cv/decode
import yaml2cv/cv/draft.{
  Contact, Draft, Entries, Entry, Link, Person, Section, Skill, Skills, Text,
}
import yaml2cv/cv/draft/emit

fn example() -> String {
  let assert Ok(yaml) = simplifile.read("priv/examples/example.yaml")
  yaml
}

pub fn emits_example_canonically_test() {
  let assert Ok(cv) = draft.from_yaml(example())
  cv
  |> emit.to_yaml
  |> birdie.snap(title: "example cv as canonical yaml")
}

pub fn round_trips_example_test() {
  let assert Ok(cv) = draft.from_yaml(example())
  let yaml = emit.to_yaml(cv)
  assert draft.from_yaml(yaml) == Ok(cv)
  assert decode.from_yaml(yaml) == decode.from_yaml(example())
}

pub fn emits_empty_draft_test() {
  assert emit.to_yaml(draft.empty)
    == "schema_version: 1\n\nperson:\n  name: \"\"\n\nsections: []\n"
}

pub fn keeps_empty_required_fields_test() {
  let cv =
    Draft(
      ..draft.empty,
      contact: Contact(..draft.empty.contact, links: [Link(label: "", url: "")]),
      sections: [
        Section(name: "", content: Entries([draft.blank_entry])),
        Section(name: "", content: Skills([Skill(name: "", level: "")])),
        Section(name: "", content: Text("")),
        Section(name: "", content: Entries([])),
      ],
    )
  assert draft.from_yaml(emit.to_yaml(cv)) == Ok(cv)
}

const tricky_values = [
  "plain text", "2021", "007", "1.50", "true", "False", "null", "~", "yes",
  "- dash", "key: value", "a #comment", "#hash", "trailing ", " leading",
  "say \"hi\"", "back\\slash", "tab\there", "[flow]", "{map}", "*alias",
  "&anchor", "!tag", "|", ">", "'single'", "%percent", "@at", "`tick`",
  "ends with:", "?", "", "ümlaut ✓", "--- doc", "...", "? key", "a: b: c",
]

pub fn quotes_scalars_that_would_change_meaning_test() {
  list.each(tricky_values, fn(value) {
    let cv =
      Draft(..draft.empty, person: Person(..draft.empty.person, title: value))
    let assert Ok(read) = draft.from_yaml(emit.to_yaml(cv))
      as { "round trip of " <> value }
    assert read.person.title == value
  })
}

pub fn writes_plain_scalars_when_safe_test() {
  let cv =
    Draft(
      ..draft.empty,
      person: Person(
        name: "Jane Roe",
        title: "2021",
        address: "1.50",
        photo: "",
      ),
    )
  assert emit.to_yaml(cv)
    == "schema_version: 1\n\nperson:\n  name: Jane Roe\n  title: 2021\n  address: \"1.50\"\n\nsections: []\n"
}

pub fn round_trips_multi_line_text_test() {
  let texts = [
    "one\ntwo", "one\ntwo\n", "one\ntwo\n\n", "one\n\nthree", " indented\nnext",
    "\nleading newline", "line with trailing space \nnext", "tab\tin\nblock",
  ]
  list.each(texts, fn(text) {
    let cv =
      Draft(..draft.empty, sections: [
        Section(name: "About", content: Text(text)),
      ])
    assert draft.from_yaml(emit.to_yaml(cv)) == Ok(cv)
  })
}

pub fn uses_block_scalars_for_multi_line_text_test() {
  let cv =
    Draft(..draft.empty, sections: [
      Section(name: "About", content: Text("Hello.\nSecond line.\n")),
    ])
  assert emit.to_yaml(cv)
    == "schema_version: 1\n\nperson:\n  name: \"\"\n\nsections:\n  - name: About\n    kind: text\n    text: |\n      Hello.\n      Second line.\n"
}

pub fn round_trips_bullets_test() {
  let cv =
    Draft(..draft.empty, sections: [
      Section(
        name: "Work",
        content: Entries([
          Entry(..draft.blank_entry, bullets: tricky_values),
        ]),
      ),
    ])
  assert draft.from_yaml(emit.to_yaml(cv)) == Ok(cv)
}

pub fn round_trips_photo_and_photo_shape_test() {
  let assert Ok(bytes) = simplifile.read_bits("test/fixtures/photo.jpg")
  let uri = "data:image/jpeg;base64," <> bit_array.base64_encode(bytes, True)
  let cv =
    Draft(
      ..draft.empty,
      style: draft.Style(..draft.empty.style, photo_shape: "circle"),
      person: Person(..draft.empty.person, name: "Jane Roe", photo: uri),
    )
  let yaml = emit.to_yaml(cv)
  assert draft.from_yaml(yaml) == Ok(cv)
  let assert Ok(decoded) = decode.from_yaml(yaml)
  assert decoded.person.photo != option.None
}

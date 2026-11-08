import simplifile
import yaml2cv/cv/draft.{
  Contact, Draft, Entries, Entry, Link, Section, Skill, Skills, Text,
}
import yaml2cv/web/visual_form.{
  Add, AddSection, Bullets, EntriesOf, Links, MoveDown, MoveUp, Remove, Sections,
  SkillsOf,
}

fn example() -> draft.Draft {
  let assert Ok(yaml) = simplifile.read("priv/examples/example.yaml")
  let assert Ok(cv) = draft.from_yaml(yaml)
  cv
}

fn sample() -> draft.Draft {
  Draft(
    ..draft.empty,
    contact: Contact(..draft.empty.contact, links: [
      Link("A", "a"),
      Link("B", "b"),
    ]),
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
      Section("Empty", Entries([])),
    ],
  )
}

pub fn round_trips_fields_test() {
  assert visual_form.parse(visual_form.fields(example())) == example()
  assert visual_form.parse(visual_form.fields(sample())) == sample()
}

pub fn names_fields_by_path_test() {
  let fields = visual_form.fields(sample())
  let assert Ok("One") = key_find(fields, "sections.0.entries.0.title")
  let assert Ok("y") = key_find(fields, "sections.0.entries.0.bullets.1")
  let assert Ok("English") = key_find(fields, "sections.1.items.0.name")
  let assert Ok("text") = key_find(fields, "sections.2.kind")
  let assert Ok("Hi") = key_find(fields, "sections.2.text")
  let assert Ok("b") = key_find(fields, "contact.links.1.url")
}

fn key_find(fields, key) {
  case fields {
    [] -> Error(Nil)
    [#(k, v), ..] if k == key -> Ok(v)
    [_, ..rest] -> key_find(rest, key)
  }
}

pub fn normalises_line_breaks_test() {
  let cv =
    visual_form.parse([
      #("sections.0.kind", "text"),
      #("sections.0.name", "About"),
      #("sections.0.text", "a\r\nb"),
    ])
  assert cv.sections == [Section("About", Text("a\nb"))]
}

pub fn ignores_unknown_kinds_and_huge_indices_test() {
  let cv =
    visual_form.parse([
      #("sections.0.kind", "gallery"),
      #("sections.99999999.kind", "text"),
      #("contact.links.123456789.label", "x"),
    ])
  assert cv.sections == [draft.blank_section("entries")]
  assert cv.contact.links == []
}

pub fn parses_ops_test() {
  assert visual_form.parse_op("add-section:skills") == Ok(AddSection("skills"))
  assert visual_form.parse_op("add:contact.links") == Ok(Add(Links))
  assert visual_form.parse_op("add:sections.1.entries") == Ok(Add(EntriesOf(1)))
  assert visual_form.parse_op("add:sections.1.items") == Ok(Add(SkillsOf(1)))
  assert visual_form.parse_op("add:sections.1.entries.0.bullets")
    == Ok(Add(Bullets(1, 0)))
  assert visual_form.parse_op("remove:sections.2") == Ok(Remove(Sections, 2))
  assert visual_form.parse_op("up:sections.1.entries.0.bullets.3")
    == Ok(MoveUp(Bullets(1, 0), 3))
  assert visual_form.parse_op("down:contact.links.0") == Ok(MoveDown(Links, 0))
  assert visual_form.parse_op("add-section:gallery") == Error(Nil)
  assert visual_form.parse_op("explode:sections.1") == Error(Nil)
  assert visual_form.parse_op("remove:sections.x") == Error(Nil)
}

pub fn adds_blocks_test() {
  let cv = sample()
  let assert [_, _, _, _, Section("", Text(""))] =
    visual_form.apply(cv, AddSection("text")).sections
  let assert [_, _, Link("", "")] =
    visual_form.apply(cv, Add(Links)).contact.links
  let assert [Section(_, Entries([_, _, entry])), ..] =
    visual_form.apply(cv, Add(EntriesOf(0))).sections
  assert entry == draft.blank_entry
  let assert [_, Section(_, Skills([_, Skill("", "")])), ..] =
    visual_form.apply(cv, Add(SkillsOf(1))).sections
  let assert [Section(_, Entries([Entry(bullets: ["x", "y", ""], ..), _])), ..] =
    visual_form.apply(cv, Add(Bullets(0, 0))).sections
}

pub fn removes_and_moves_blocks_test() {
  let cv = sample()
  let assert [Link("B", "b")] =
    visual_form.apply(cv, Remove(Links, 0)).contact.links
  let assert [Section("Langs", _), Section("Work", _), ..] =
    visual_form.apply(cv, MoveUp(Sections, 1)).sections
  let assert [Section("Langs", _), Section("Work", _), ..] =
    visual_form.apply(cv, MoveDown(Sections, 0)).sections
  let assert [Section(_, Entries([Entry(bullets: ["y", "x"], ..), _])), ..] =
    visual_form.apply(cv, MoveDown(Bullets(0, 0), 0)).sections
}

pub fn ignores_out_of_range_ops_test() {
  let cv = sample()
  assert visual_form.apply(cv, MoveUp(Sections, 0)) == cv
  assert visual_form.apply(cv, MoveDown(Sections, 3)) == cv
  assert visual_form.apply(cv, Remove(Links, 5)) == cv
  assert visual_form.apply(cv, Add(SkillsOf(0))) == cv
  assert visual_form.apply(cv, Add(EntriesOf(9))) == cv
  assert visual_form.apply(cv, Add(Bullets(1, 0))) == cv
}

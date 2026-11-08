import gleam/option.{None, Some}
import gleam/string
import simplifile
import yaml2cv/cv.{
  Blue, Classic, Contact, Cv, Entries, Entry, Link, Person, Section, Skill,
  Skills, Style, Text,
}
import yaml2cv/cv/decode.{
  DocumentTooComplex, DocumentTooLarge, SchemaError, SyntaxError,
}
import yaml2cv/yaml

const minimal =
  "
schema_version: 1
person:
  name: Jane Roe
sections: []
"

pub fn decodes_minimal_document_with_defaults_test() {
  assert decode.from_yaml(minimal)
    == Ok(
      Cv(
        style: Style(theme: Classic, color: Blue),
        person: Person(name: "Jane Roe", title: None, address: None),
        contact: Contact(email: None, phone: None, website: None, links: []),
        sections: [],
      ),
    )
}

pub fn decodes_all_section_kinds_test() {
  let yaml =
    "
schema_version: 1
person: { name: Jane Roe }
contact:
  email: jane@example.com
  links: [{ label: GitHub, url: https://github.com/jane }]
sections:
  - name: Work
    entries:
      - timespan: 2021
        title: Engineer
        location: Berlin
        bullets: [Built things]
  - name: Languages
    kind: skills
    items: [{ name: English, level: Native }, { name: Esperanto }]
  - name: About
    kind: text
    text: Hello there.
"

  let assert Ok(cv) = decode.from_yaml(yaml)
  assert cv.contact.email == Some("jane@example.com")
  assert cv.contact.links
    == [Link(label: "GitHub", url: "https://github.com/jane")]
  assert cv.sections
    == [
      Section(
        name: "Work",
        content: Entries([
          Entry(
            timespan: "2021",
            title: "Engineer",
            organization: None,
            location: Some("Berlin"),
            bullets: ["Built things"],
          ),
        ]),
      ),
      Section(
        name: "Languages",
        content: Skills([
          Skill(name: "English", level: Some("Native")),
          Skill(name: "Esperanto", level: None),
        ]),
      ),
      Section(name: "About", content: Text("Hello there.")),
    ]
}

pub fn decodes_example_fixture_test() {
  let assert Ok(yaml) = simplifile.read("priv/examples/example.yaml")
  let assert Ok(cv) = decode.from_yaml(yaml)
  assert cv.person.name == "John Doe"
  assert cv.contact.phone == Some("0123 4 56 78 90")
  let assert [_, _, _, Section(name: "Languages", content: Skills(_))] =
    cv.sections
}

pub fn reports_yaml_syntax_error_with_location_test() {
  let assert Error([SyntaxError(line: 2, ..)]) =
    decode.from_yaml("person:\n  name: [unclosed\n")
}

pub fn rejects_non_mapping_root_test() {
  assert decode.from_yaml("- a list")
    == Error([SchemaError(path: "", message: "expected a mapping")])
}

pub fn rejects_empty_document_test() {
  assert decode.from_yaml("")
    == Error([SchemaError(path: "", message: "expected a mapping")])
}

pub fn rejects_unsupported_schema_version_test() {
  assert decode.from_yaml("schema_version: 2\nperson: {name: X}\nsections: []")
    == Error([
      SchemaError(
        path: "schema_version",
        message: "unsupported version 2, expected 1",
      ),
    ])
}

pub fn collects_all_errors_with_paths_test() {
  let yaml =
    "
schema_version: 1
style: { color: pink }
person: { title: Boss }
sections:
  - name: Work
    entries:
      - title: Engineer
        city: Berlin
  - name: Misc
    kind: gallery
nickname: JR
"

  assert decode.from_yaml(yaml)
    == Error([
      SchemaError(
        path: "style.color",
        message: "expected one of: black, blue, burgundy, green, grey, orange, purple, red",
      ),
      SchemaError(path: "person.name", message: "is required"),
      SchemaError(
        path: "sections[0].entries[0].timespan",
        message: "is required",
      ),
      SchemaError(path: "sections[0].entries[0].city", message: "unknown key"),
      SchemaError(
        path: "sections[1].kind",
        message: "expected one of: entries, skills, text",
      ),
      SchemaError(path: "nickname", message: "unknown key"),
    ])
}

pub fn rejects_wrong_types_and_blank_text_test() {
  let yaml =
    "
schema_version: 1
person: { name: '  ', title: [a, b], address: true }
sections: { name: Work }
"

  assert decode.from_yaml(yaml)
    == Error([
      SchemaError(path: "person.name", message: "must not be empty"),
      SchemaError(path: "person.title", message: "expected text"),
      SchemaError(path: "person.address", message: "expected text"),
      SchemaError(path: "sections", message: "expected a list"),
    ])
}

pub fn rejects_multiple_documents_test() {
  assert decode.from_yaml(minimal <> "---\n" <> minimal)
    == Error([
      SchemaError(path: "", message: "expected exactly one YAML document"),
    ])
}

pub fn rejects_documents_with_too_many_nodes_test() {
  // Block style: yamerl parses long flow collections in quadratic time.
  let yaml = string.repeat("- x\n", yaml.max_nodes + 1)
  assert decode.from_yaml(yaml)
    == Error([DocumentTooLarge(max_nodes: yaml.max_nodes)])
}

pub fn rejects_documents_too_complex_to_parse_in_time_test() {
  let yaml = string.repeat("[", 30_000) <> string.repeat("]", 30_000)
  assert decode.from_yaml(yaml) == Error([DocumentTooComplex])
}

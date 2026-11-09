import simplifile
import yaml2cv/cv/decode.{SchemaError, SyntaxError}
import yaml2cv/cv/draft.{
  Contact, Draft, Entries, Entry, Link, Person, Section, Skill, Skills, Style,
  Text,
}

pub fn reads_every_block_test() {
  let yaml =
    "
schema_version: 1
style: { theme: minimal, color: red }
person: { name: Jane Roe, title: Engineer }
contact:
  email: jane@example.com
  links: [{ label: GitHub, url: https://github.com/jane }]
sections:
  - name: Work
    entries:
      - timespan: 2021
        title: Engineer
        location: Berlin
        bullets: [Built things, 42]
  - name: Languages
    kind: skills
    items: [{ name: English, level: Native }, { name: Esperanto }]
  - name: About
    kind: text
    text: |
      Hello there.
      Second line.
"

  assert draft.from_yaml(yaml)
    == Ok(
      Draft(
        language: "",
        style: Style(theme: "minimal", color: "red", paper: "", photo_shape: ""),
        person: Person(
          name: "Jane Roe",
          title: "Engineer",
          address: "",
          photo: "",
        ),
        contact: Contact(
          email: "jane@example.com",
          phone: "",
          website: "",
          links: [
            Link(label: "GitHub", url: "https://github.com/jane"),
          ],
        ),
        sections: [
          Section(
            name: "Work",
            content: Entries([
              Entry(
                timespan: "2021",
                title: "Engineer",
                organization: "",
                location: "Berlin",
                bullets: ["Built things", "42"],
              ),
            ]),
          ),
          Section(
            name: "Languages",
            content: Skills([
              Skill(name: "English", level: "Native"),
              Skill(name: "Esperanto", level: ""),
            ]),
          ),
          Section(name: "About", content: Text("Hello there.\nSecond line.\n")),
        ],
      ),
    )
}

pub fn reads_example_fixture_test() {
  let assert Ok(yaml) = simplifile.read("priv/examples/example.yaml")
  let assert Ok(cv) = draft.from_yaml(yaml)
  assert cv.person.name == "John Doe"
}

pub fn accepts_missing_and_empty_required_values_test() {
  let yaml =
    "
person: { name: '' }
sections:
  - kind: skills
    items: [{ level: Native }]
  - name: Empty
"

  assert draft.from_yaml(yaml)
    == Ok(
      Draft(
        language: "",
        style: draft.empty.style,
        person: draft.empty.person,
        contact: draft.empty.contact,
        sections: [
          Section(name: "", content: Skills([Skill(name: "", level: "Native")])),
          Section(name: "Empty", content: Entries([])),
        ],
      ),
    )
}

pub fn reads_empty_document_as_empty_draft_test() {
  assert draft.from_yaml("") == Ok(draft.empty)
}

pub fn rejects_what_blocks_cannot_show_test() {
  let yaml =
    "
schema_version: 1
style: { color: pink }
person: { name: [a, b] }
contact: { links: { label: x } }
sections:
  - name: Work
    entries:
      - title: Engineer
        city: Berlin
  - name: Misc
    kind: gallery
  - name: About
    kind: text
    entries: []
nickname: JR
"

  assert draft.from_yaml(yaml)
    == Error([
      SchemaError(
        path: "style.color",
        problem: decode.ExpectedOneOf([
          "black",
          "blue",
          "burgundy",
          "green",
          "grey",
          "orange",
          "purple",
          "red",
        ]),
      ),
      SchemaError(path: "person.name", problem: decode.ExpectedText),
      SchemaError(path: "contact.links", problem: decode.ExpectedList),
      SchemaError(
        path: "sections[0].entries[0].city",
        problem: decode.UnknownKey,
      ),
      SchemaError(
        path: "sections[1].kind",
        problem: decode.ExpectedOneOf(["entries", "skills", "text"]),
      ),
      SchemaError(path: "sections[2].entries", problem: decode.UnknownKey),
      SchemaError(path: "nickname", problem: decode.UnknownKey),
    ])
}

pub fn rejects_unsupported_schema_version_test() {
  assert draft.from_yaml("schema_version: 2")
    == Error([
      SchemaError(
        path: "schema_version",
        problem: decode.UnsupportedVersion(found: 2, supported: 1),
      ),
    ])
}

pub fn rejects_syntax_errors_test() {
  let assert Error([SyntaxError(line: 2, ..)]) =
    draft.from_yaml("person:\n  name: [unclosed\n")
}

pub fn rejects_non_mapping_root_test() {
  assert draft.from_yaml("- a list")
    == Error([SchemaError(path: "", problem: decode.ExpectedMapping)])
}

pub fn reads_language_test() {
  let assert Ok(read) =
    draft.from_yaml(
      "schema_version: 1\nlanguage: de\nperson: { name: X }\nsections: []\n",
    )
  assert read.language == "de"
}

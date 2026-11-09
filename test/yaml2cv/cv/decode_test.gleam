import gleam/bit_array
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import simplifile
import yaml2cv/cv.{
  A4, Blue, Circle, Classic, Contact, Cover, Cv, Entries, Entry, Letter, Link,
  Minimal, Person, Photo, Png, Rectangle, Section, Skill, Skills, Spotlight,
  Studio, Style, Text,
}
import yaml2cv/cv/decode.{
  DocumentTooComplex, DocumentTooLarge, InvalidPhoto, SchemaError, SyntaxError,
}
import yaml2cv/cv/photo
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
        language: cv.default_language,
        style: Style(
          theme: Classic,
          color: Blue,
          paper: A4,
          photo_shape: Rectangle,
        ),
        person: Person(
          name: "Jane Roe",
          title: None,
          address: None,
          photo: None,
        ),
        contact: Contact(email: None, phone: None, website: None, links: []),
        sections: [],
      ),
    )
}

pub fn decodes_minimal_theme_test() {
  let assert Ok(cv) =
    decode.from_yaml(
      "
schema_version: 1
style: { theme: minimal }
person: { name: Jane Roe }
sections: []
",
    )
  assert cv.style
    == Style(theme: Minimal, color: Blue, paper: A4, photo_shape: Rectangle)
}

pub fn decodes_studio_theme_test() {
  let assert Ok(cv) =
    decode.from_yaml(
      "
schema_version: 1
style: { theme: studio }
person: { name: Jane Roe }
sections: []
",
    )
  assert cv.style.theme == Studio
}

pub fn decodes_spotlight_theme_test() {
  let assert Ok(cv) =
    decode.from_yaml(
      "
schema_version: 1
style: { theme: spotlight }
person: { name: Jane Roe }
sections: []
",
    )
  assert cv.style.theme == Spotlight
}

pub fn decodes_cover_theme_test() {
  let assert Ok(cv) =
    decode.from_yaml(
      "
schema_version: 1
style: { theme: cover }
person: { name: Jane Roe }
sections: []
",
    )
  assert cv.style.theme == Cover
}

pub fn decodes_paper_size_test() {
  let assert Ok(cv) =
    decode.from_yaml(
      "
schema_version: 1
style: { paper: letter }
person: { name: Jane Roe }
sections: []
",
    )
  assert cv.style.paper == Letter
}

pub fn rejects_unknown_paper_size_test() {
  let assert Error([SchemaError(path: "style.paper", ..)]) =
    decode.from_yaml(
      "
schema_version: 1
style: { paper: a3 }
person: { name: Jane Roe }
sections: []
",
    )
}

pub fn decodes_photo_shape_test() {
  let assert Ok(cv) =
    decode.from_yaml(
      "
schema_version: 1
style: { photo_shape: circle }
person: { name: Jane Roe }
sections: []
",
    )
  assert cv.style.photo_shape == Circle
}

pub fn rejects_unknown_photo_shape_test() {
  let assert Error([SchemaError(path: "style.photo_shape", ..)]) =
    decode.from_yaml(
      "
schema_version: 1
style: { photo_shape: hexagon }
person: { name: Jane Roe }
sections: []
",
    )
}

pub fn decodes_photo_data_uri_test() {
  let assert Ok(bytes) = simplifile.read_bits("test/fixtures/photo.png")
  let uri = "data:image/png;base64," <> bit_array.base64_encode(bytes, True)
  let assert Ok(cv) = decode.from_yaml("
schema_version: 1
person:
  name: Jane Roe
  photo: " <> uri <> "
sections: []
")
  assert cv.person.photo == Some(Photo(format: Png, data: bytes))
}

pub fn rejects_photo_that_is_not_a_data_uri_test() {
  assert decode.from_yaml(
      "
schema_version: 1
person: { name: Jane Roe, photo: /etc/passwd }
sections: []
",
    )
    == Error([
      SchemaError(
        path: "person.photo",
        problem: InvalidPhoto(photo.NotAPhotoDataUri),
      ),
    ])
}

pub fn photo_errors_do_not_repeat_the_photo_test() {
  let assert Error([SchemaError(problem:, ..)]) =
    decode.from_yaml(
      "
schema_version: 1
person: { name: Jane Roe, photo: 'data:image/png;base64,c2VjcmV0' }
sections: []
",
    )
  assert problem == InvalidPhoto(photo.InvalidImage)
  assert !string.contains(decode.describe(problem), "c2VjcmV0")
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
    == Error([SchemaError(path: "", problem: decode.ExpectedMapping)])
}

pub fn rejects_empty_document_test() {
  assert decode.from_yaml("")
    == Error([SchemaError(path: "", problem: decode.ExpectedMapping)])
}

pub fn rejects_unsupported_schema_version_test() {
  assert decode.from_yaml("schema_version: 2\nperson: {name: X}\nsections: []")
    == Error([
      SchemaError(
        path: "schema_version",
        problem: decode.UnsupportedVersion(found: 2, supported: 1),
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
      SchemaError(path: "person.name", problem: decode.Required),
      SchemaError(
        path: "sections[0].entries[0].timespan",
        problem: decode.Required,
      ),
      SchemaError(
        path: "sections[0].entries[0].city",
        problem: decode.UnknownKey,
      ),
      SchemaError(
        path: "sections[1].kind",
        problem: decode.ExpectedOneOf(["entries", "skills", "text"]),
      ),
      SchemaError(path: "nickname", problem: decode.UnknownKey),
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
      SchemaError(path: "person.name", problem: decode.MustNotBeEmpty),
      SchemaError(path: "person.title", problem: decode.ExpectedText),
      SchemaError(path: "person.address", problem: decode.ExpectedText),
      SchemaError(path: "sections", problem: decode.ExpectedList),
    ])
}

pub fn rejects_multiple_documents_test() {
  assert decode.from_yaml(minimal <> "---\n" <> minimal)
    == Error([
      SchemaError(path: "", problem: decode.ExpectedOneDocument),
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

pub fn accepts_every_exported_section_kind_with_its_content_key_test() {
  list.each(decode.section_kinds, fn(kind) {
    let #(name, key) = kind
    let content = case key {
      "text" -> " Some text."
      _ -> " []"
    }
    let source =
      "schema_version: 1\nperson: {name: X}\nsections:\n  - name: S\n    kind: "
      <> name
      <> "\n    "
      <> key
      <> ":"
      <> content
      <> "\n"
    let assert Ok(_) = decode.from_yaml(source)
  })
}

pub fn describe_problem_in_english_test() {
  assert list.map(
      [
        decode.ExpectedMapping,
        decode.ExpectedOneDocument,
        decode.UnsupportedVersion(found: 2, supported: 1),
        decode.ExpectedInteger,
        decode.Required,
        decode.UnknownKey,
        decode.MustNotBeEmpty,
        decode.ExpectedText,
        decode.ExpectedList,
        decode.ExpectedOneOf(["a", "b"]),
        decode.ExpectedLanguageCode,
      ],
      decode.describe,
    )
    == [
      "expected a mapping",
      "expected exactly one YAML document",
      "unsupported version 2, expected 1",
      "expected an integer",
      "is required",
      "unknown key",
      "must not be empty",
      "expected text",
      "expected a list",
      "expected one of: a, b",
      "expected a two-letter language code such as en or de",
    ]
}

pub fn decodes_language_test() {
  let assert Ok(document) =
    decode.from_yaml(
      "
schema_version: 1
language: de
person: { name: Jane Roe }
sections: []
",
    )
  assert cv.language_code(document.language) == "de"
}

pub fn defaults_language_to_english_test() {
  let assert Ok(document) = decode.from_yaml(minimal)
  assert cv.language_code(document.language) == "en"
}

pub fn rejects_malformed_language_test() {
  use value <- list.each(["German", "DE", "d", "de-DE", "deu", "1", "''"])
  let source =
    "schema_version: 1\nlanguage: "
    <> value
    <> "\nperson: { name: Jane Roe }\nsections: []\n"
  assert #(value, decode.from_yaml(source))
    == #(
      value,
      Error([
        SchemaError(path: "language", problem: decode.ExpectedLanguageCode),
      ]),
    )
}

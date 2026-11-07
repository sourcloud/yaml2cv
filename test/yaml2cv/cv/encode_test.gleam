import birdie
import gleam/json
import simplifile
import yaml2cv/cv/decode
import yaml2cv/cv/encode

pub fn encodes_example_cv_test() {
  let assert Ok(yaml) = simplifile.read("test/fixtures/example.yaml")
  let assert Ok(cv) = decode.from_yaml(yaml)

  cv
  |> encode.to_json
  |> json.to_string
  |> birdie.snap(title: "example cv as json")
}

pub fn encodes_missing_optional_values_as_null_test() {
  let assert Ok(cv) =
    decode.from_yaml(
      "
schema_version: 1
person: { name: Jane Roe }
sections:
  - { name: About, kind: text, text: Hi. }
",
    )

  assert json.to_string(encode.to_json(cv))
    == "{\"style\":{\"theme\":\"classic\",\"color\":\"blue\"},"
    <> "\"person\":{\"name\":\"Jane Roe\",\"title\":null,\"address\":null},"
    <> "\"contact\":{\"email\":null,\"phone\":null,\"website\":null,\"links\":[]},"
    <> "\"sections\":[{\"name\":\"About\",\"kind\":\"text\",\"text\":\"Hi.\"}]}"
}

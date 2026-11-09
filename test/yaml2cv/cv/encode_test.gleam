import birdie
import gleam/bit_array
import gleam/json
import gleam/string
import simplifile
import yaml2cv/cv/decode
import yaml2cv/cv/encode

pub fn encodes_example_cv_test() {
  let assert Ok(yaml) = simplifile.read("priv/examples/example.yaml")
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
    == "{\"language\":\"en\",\"style\":{\"theme\":\"classic\",\"color\":\"blue\",\"paper\":\"a4\",\"photo_shape\":\"rectangle\"},"
    <> "\"person\":{\"name\":\"Jane Roe\",\"title\":null,\"address\":null,\"photo\":null},"
    <> "\"contact\":{\"email\":null,\"phone\":null,\"website\":null,\"links\":[]},"
    <> "\"sections\":[{\"name\":\"About\",\"kind\":\"text\",\"text\":\"Hi.\"}]}"
}

pub fn encodes_photo_as_file_name_not_bytes_test() {
  let assert Ok(bytes) = simplifile.read_bits("test/fixtures/photo.jpg")
  let uri = "data:image/jpeg;base64," <> bit_array.base64_encode(bytes, True)
  let assert Ok(cv) = decode.from_yaml("
schema_version: 1
person: { name: Jane Roe, photo: '" <> uri <> "' }
sections: []
")
  let encoded = json.to_string(encode.to_json(cv))
  assert string.contains(encoded, "\"photo\":\"photo.jpg\"")
  assert !string.contains(encoded, "base64")
}

//// Third-party components shipped with yaml2cv and their license texts
//// (ADR 0013, ADR 0032). The image build writes them as JSON; the licenses
//// page reads them.

import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import simplifile

/// A third-party package or asset.
pub type Component {
  Component(
    name: String,
    version: String,
    /// SPDX identifiers; empty when the component does not declare any.
    licenses: List(String),
    files: List(LicenseFile),
    /// Where to get the source code, for licenses that require offering it.
    sources: List(Source),
  )
}

/// A download of a component's source code.
pub type Source {
  Source(description: String, url: String)
}

/// A license or notice file of a component.
pub type LicenseFile {
  LicenseFile(name: String, text: String)
}

/// Encodes components as the notices JSON document.
pub fn to_json(components: List(Component)) -> String {
  json.object([
    #(
      "components",
      json.array(components, fn(component) {
        json.object([
          #("name", json.string(component.name)),
          #("version", json.string(component.version)),
          #("licenses", json.array(component.licenses, json.string)),
          #(
            "files",
            json.array(component.files, fn(file) {
              json.object([
                #("name", json.string(file.name)),
                #("text", json.string(file.text)),
              ])
            }),
          ),
          #(
            "sources",
            json.array(component.sources, fn(source) {
              json.object([
                #("description", json.string(source.description)),
                #("url", json.string(source.url)),
              ])
            }),
          ),
        ])
      }),
    ),
  ])
  |> json.to_string
}

/// Decodes the notices JSON document written by `to_json`.
pub fn from_json(source: String) -> Result(List(Component), json.DecodeError) {
  let file = {
    use name <- decode.field("name", decode.string)
    use text <- decode.field("text", decode.string)
    decode.success(LicenseFile(name:, text:))
  }
  let source_decoder = {
    use description <- decode.field("description", decode.string)
    use url <- decode.field("url", decode.string)
    decode.success(Source(description:, url:))
  }
  let component = {
    use name <- decode.field("name", decode.string)
    use version <- decode.field("version", decode.string)
    use licenses <- decode.field("licenses", decode.list(decode.string))
    use files <- decode.field("files", decode.list(file))
    use sources <- decode.optional_field(
      "sources",
      [],
      decode.list(source_decoder),
    )
    decode.success(Component(name:, version:, licenses:, files:, sources:))
  }
  json.parse(source, decode.at(["components"], decode.list(component)))
}

/// Reads the notices JSON at `path`. A missing file means no notices, as
/// when running from source; an unreadable or invalid one is an error.
pub fn load(path: String) -> Result(List(Component), String) {
  case simplifile.read(path) {
    Error(simplifile.Enoent) -> Ok([])
    Error(error) -> Error(path <> ": " <> simplifile.describe_error(error))
    Ok(source) ->
      from_json(source)
      |> result.replace_error(path <> ": invalid notices JSON")
  }
}

/// The directory name for a component's license files: lower case, with
/// characters other than letters, digits, `_`, `.` and `-` replaced by `-`.
pub fn slug(name: String) -> String {
  name
  |> string.lowercase
  |> string.to_graphemes
  |> list.map(fn(char) {
    case string.contains("abcdefghijklmnopqrstuvwxyz0123456789_.-", char) {
      True -> char
      False -> "-"
    }
  })
  |> string.concat
}

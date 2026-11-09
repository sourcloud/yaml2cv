//// Generates third-party license notices for the packages in an Erlang
//// shipment and for further components (ADR 0013, ADR 0032). Dev-only; run
//// from the project root after `gleam export erlang-shipment`:
////
////     gleam run -m notices -- build/erlang-shipment <output directory> \
////       [--components third_party.toml]... \
////       [--component 'Name|version|License|file,file']... \
////       [--json <path>]
////
//// Writes `<output>/THIRD_PARTY_NOTICES.md` and `<output>/licenses/<slug>/`,
//// and with `--json` the components and license texts as JSON.

import argv
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import simplifile
import tom
import yaml2cv/notices.{
  type Component, type LicenseFile, type Source, Component, LicenseFile, Source,
}

/// A dependency as locked in `manifest.toml`.
pub type Package {
  Package(name: String, version: String, otp_app: String)
}

/// A component declared in a components file or on the command line; its
/// license files are paths relative to the working directory.
pub type Declared {
  Declared(
    name: String,
    version: String,
    licenses: List(String),
    files: List(String),
    sources: List(Source),
  )
}

/// The parsed command line.
pub type Arguments {
  Arguments(
    shipment: String,
    output: String,
    /// TOML files declaring components (`--components`).
    component_files: List(String),
    /// Inline component declarations (`--component`).
    components: List(String),
    json: Option(String),
  )
}

/// The application itself; it needs no third-party notice.
const own_app = "yaml2cv"

const usage =
  "usage: gleam run -m notices -- <shipment> <output> [--components <toml>]... [--component 'Name|version|License|file,file']... [--json <path>]"

pub fn main() -> Nil {
  case parse_arguments(argv.load().arguments) |> result.try(run) {
    Ok(count) ->
      io.println("Wrote notices for " <> string.inspect(count) <> " components")
    Error(error) -> {
      io.println_error("error: " <> error)
      halt(1)
    }
  }
}

/// Parses the command line arguments.
pub fn parse_arguments(arguments: List(String)) -> Result(Arguments, String) {
  case arguments {
    [shipment, output, ..options] ->
      parse_options(
        options,
        Arguments(
          shipment:,
          output:,
          component_files: [],
          components: [],
          json: None,
        ),
      )
    _ -> Error(usage)
  }
}

fn parse_options(
  options: List(String),
  arguments: Arguments,
) -> Result(Arguments, String) {
  case options {
    [] ->
      Ok(
        Arguments(
          ..arguments,
          component_files: list.reverse(arguments.component_files),
          components: list.reverse(arguments.components),
        ),
      )
    ["--components", path, ..rest] ->
      parse_options(
        rest,
        Arguments(..arguments, component_files: [
          path,
          ..arguments.component_files
        ]),
      )
    ["--component", spec, ..rest] ->
      parse_options(
        rest,
        Arguments(..arguments, components: [spec, ..arguments.components]),
      )
    ["--json", path, ..rest] ->
      parse_options(rest, Arguments(..arguments, json: Some(path)))
    _ -> Error(usage)
  }
}

fn run(arguments: Arguments) -> Result(Int, String) {
  use manifest <- result.try(read("manifest.toml"))
  use packages <- result.try(parse_manifest(manifest))
  use apache <- result.try(read("LICENSE"))
  use entries <- result.try(
    simplifile.read_directory(arguments.shipment)
    |> result.map_error(describe(arguments.shipment, _)),
  )
  let apps =
    entries
    |> list.filter(fn(entry) {
      entry != own_app
      && simplifile.is_directory(arguments.shipment <> "/" <> entry) == Ok(True)
    })
  use from_packages <- result.try(
    list.try_map(apps, component_for(_, packages, apache)),
  )
  use from_files <- result.try(
    list.try_map(arguments.component_files, fn(path) {
      read(path) |> result.try(parse_components)
    }),
  )
  use from_flags <- result.try(list.try_map(
    arguments.components,
    parse_component,
  ))
  use declared <- result.try(
    list.flatten([list.flatten(from_files), from_flags])
    |> list.try_map(resolve),
  )
  let components =
    list.append(from_packages, declared)
    |> list.sort(fn(a, b) {
      string.compare(string.lowercase(a.name), string.lowercase(b.name))
    })
  use _ <- result.try(write_notices(components, arguments.output))
  use _ <- result.try(case arguments.json {
    Some(path) ->
      simplifile.write(to: path, contents: notices.to_json(components))
      |> result.map_error(describe(path, _))
    None -> Ok(Nil)
  })
  Ok(list.length(components))
}

fn component_for(
  app: String,
  packages: List(Package),
  apache: String,
) -> Result(Component, String) {
  use package <- result.try(
    list.find(packages, fn(package) { package.otp_app == app })
    |> result.replace_error(app <> ": not found in manifest.toml"),
  )
  let directory = "build/packages/" <> package.name
  let metadata =
    read(directory <> "/gleam.toml")
    |> result.lazy_or(fn() { read(directory <> "/src/" <> app <> ".app.src") })
    |> result.unwrap("")
  let licenses = declared_licenses(metadata)
  use files <- result.try(license_files(directory))
  use files <- result.try(license_texts(package.name, licenses, files, apache:))
  Ok(
    Component(
      name: package.name,
      version: package.version,
      licenses:,
      files:,
      sources: [],
    ),
  )
}

/// Reads the license files of a declared component.
fn resolve(declared: Declared) -> Result(Component, String) {
  use files <- result.try(
    list.try_map(declared.files, fn(path) {
      read(path)
      |> result.map(fn(text) { LicenseFile(name: basename(path), text:) })
    }),
  )
  Ok(Component(
    name: declared.name,
    version: declared.version,
    licenses: declared.licenses,
    files:,
    sources: declared.sources,
  ))
}

fn basename(path: String) -> String {
  string.split(path, "/") |> list.last |> result.unwrap(path)
}

/// Parses the locked packages from the contents of `manifest.toml`.
pub fn parse_manifest(source: String) -> Result(List(Package), String) {
  let invalid = "manifest.toml: unexpected format"
  use toml <- result.try(
    tom.parse(source) |> result.replace_error("manifest.toml: invalid TOML"),
  )
  use entries <- result.try(
    tom.get_array(toml, ["packages"]) |> result.replace_error(invalid),
  )
  list.try_map(entries, fn(entry) {
    use table <- result.try(
      tom.as_table(entry) |> result.replace_error(invalid),
    )
    let field = fn(key) {
      tom.get_string(table, [key]) |> result.replace_error(invalid)
    }
    use name <- result.try(field("name"))
    use version <- result.try(field("version"))
    let otp_app = field("otp_app") |> result.unwrap(name)
    Ok(Package(name:, version:, otp_app:))
  })
}

/// Parses the `[[component]]` tables of a components file such as
/// `third_party.toml`. Every component needs at least one license file.
pub fn parse_components(source: String) -> Result(List(Declared), String) {
  let invalid = fn(detail) { "components file: " <> detail }
  use toml <- result.try(
    tom.parse(source) |> result.replace_error(invalid("invalid TOML")),
  )
  use entries <- result.try(
    tom.get_array(toml, ["component"])
    |> result.replace_error(invalid("no [[component]] tables")),
  )
  list.try_map(entries, fn(entry) {
    use table <- result.try(
      tom.as_table(entry) |> result.replace_error(invalid("not a table")),
    )
    let string = fn(key) {
      tom.get_string(table, [key])
      |> result.replace_error(invalid("missing " <> key))
    }
    let strings = fn(key) {
      tom.get_array(table, [key])
      |> result.try(list.try_map(_, tom.as_string))
      |> result.replace_error(invalid("missing " <> key))
    }
    use name <- result.try(string("name"))
    use version <- result.try(string("version"))
    use licenses <- result.try(strings("licenses"))
    use files <- result.try(strings("files"))
    use sources <- result.try(case tom.get_array(table, ["sources"]) {
      Error(tom.NotFound(_)) -> Ok([])
      Error(_) -> Error(invalid("sources must be an array of tables"))
      Ok(sources) ->
        list.try_map(sources, fn(source) {
          let field = fn(key) {
            tom.as_table(source)
            |> result.try(tom.get_string(_, [key]))
            |> result.replace_error(invalid("source without " <> key))
          }
          use description <- result.try(field("description"))
          use url <- result.try(field("url"))
          Ok(Source(description:, url:))
        })
    })
    declared(name, version, licenses, files, sources)
  })
}

/// Parses a `--component 'Name|version|License,License|file,file'` value.
pub fn parse_component(spec: String) -> Result(Declared, String) {
  case string.split(spec, "|") {
    [name, version, licenses, files] ->
      declared(name, version, split_list(licenses), split_list(files), [])
    _ ->
      Error("--component " <> spec <> ": expected Name|version|License|files")
  }
}

fn split_list(value: String) -> List(String) {
  string.split(value, ",")
  |> list.map(string.trim)
  |> list.filter(fn(item) { item != "" })
}

fn declared(
  name: String,
  version: String,
  licenses: List(String),
  files: List(String),
  sources: List(Source),
) -> Result(Declared, String) {
  case files {
    [] -> Error(name <> ": no license files declared")
    _ -> Ok(Declared(name:, version:, licenses:, files:, sources:))
  }
}

/// License identifiers declared in package metadata: the `licences` array of
/// a `gleam.toml`, or the `licenses` entry of an Erlang `.app.src` file.
pub fn declared_licenses(metadata: String) -> List(String) {
  let from_toml = {
    use toml <- result.try(tom.parse(metadata) |> result.replace_error(Nil))
    use values <- result.try(
      tom.get_array(toml, ["licences"]) |> result.replace_error(Nil),
    )
    Ok(
      list.filter_map(values, fn(value) {
        tom.as_string(value) |> result.replace_error(Nil)
      }),
    )
  }
  case from_toml {
    Ok(licenses) -> licenses
    Error(_) -> licenses_from_app_src(metadata)
  }
}

fn licenses_from_app_src(source: String) -> List(String) {
  case string.split_once(source, "{licenses,") {
    Error(Nil) -> []
    Ok(#(_, rest)) -> {
      let inside = case string.split_once(rest, "]") {
        Ok(#(inside, _)) -> inside
        Error(Nil) -> rest
      }
      // Quoted strings sit at the odd positions when splitting on quotes.
      inside
      |> string.split("\"")
      |> list.index_map(fn(part, index) { #(part, index % 2 == 1) })
      |> list.filter_map(fn(pair) {
        case pair {
          #(part, True) -> Ok(part)
          _ -> Error(Nil)
        }
      })
    }
  }
}

fn license_files(directory: String) -> Result(List(LicenseFile), String) {
  use entries <- result.try(
    simplifile.read_directory(directory)
    |> result.map_error(describe(directory, _)),
  )
  entries
  |> list.filter(is_license_file)
  |> list.sort(string.compare)
  |> list.try_map(fn(name) {
    read(directory <> "/" <> name)
    |> result.map(fn(text) { LicenseFile(name:, text:) })
  })
}

fn is_license_file(name: String) -> Bool {
  let name = string.uppercase(name)
  list.any(["LICENSE", "LICENCE", "NOTICE", "COPYING"], string.starts_with(
    name,
    _,
  ))
}

/// Chooses the license texts to ship for a package: its own files, or the
/// standard Apache-2.0 text when that is the declared license.
pub fn license_texts(
  package: String,
  licenses: List(String),
  files: List(LicenseFile),
  apache apache: String,
) -> Result(List(LicenseFile), String) {
  case files, licenses {
    [_, ..], _ -> Ok(files)
    [], ["Apache-2.0"] -> Ok([LicenseFile(name: "LICENSE", text: apache)])
    [], _ ->
      Error(
        package
        <> ": no license file shipped and no standard text for "
        <> string.join(licenses, ", "),
      )
  }
}

/// The Markdown overview listing every component and its license files.
pub fn render_overview(components: List(Component)) -> String {
  let rows =
    list.map(components, fn(component) {
      let licenses = case component.licenses {
        [] -> "see license file"
        licenses -> string.join(licenses, ", ")
      }
      let files =
        component.files
        |> list.map(fn(file) {
          "`licenses/"
          <> notices.slug(component.name)
          <> "/"
          <> file.name
          <> "`"
        })
        |> string.join(", ")
      "| "
      <> component.name
      <> " | "
      <> component.version
      <> " | "
      <> licenses
      <> " | "
      <> files
      <> " |"
    })
  let sources =
    list.flat_map(components, fn(component) {
      list.map(component.sources, fn(source) {
        "- "
        <> component.name
        <> ": ["
        <> source.description
        <> "]("
        <> source.url
        <> ")"
      })
    })
  let sources = case sources {
    [] -> []
    _ -> [
      "",
      "## Source code",
      "",
      "Source code for components whose license requires offering it:",
      "",
      ..sources
    ]
  }
  string.join(
    [
      "# Third-party notices",
      "",
      "yaml2cv includes the following third-party components. Their license",
      "texts are in the `licenses/` directory next to this file. A running",
      "instance shows them at `/licenses`.",
      "",
      "| Component | Version | License | Files |",
      "| --- | --- | --- | --- |",
      ..list.append(rows, sources)
    ],
    "\n",
  )
  <> "\n"
}

fn write_notices(
  components: List(Component),
  output: String,
) -> Result(Nil, String) {
  use _ <- result.try(
    list.try_each(components, fn(component) {
      let directory = output <> "/licenses/" <> notices.slug(component.name)
      use _ <- result.try(
        simplifile.create_directory_all(directory)
        |> result.map_error(describe(directory, _)),
      )
      list.try_each(component.files, fn(file) {
        let path = directory <> "/" <> file.name
        simplifile.write(to: path, contents: file.text)
        |> result.map_error(describe(path, _))
      })
    }),
  )
  let path = output <> "/THIRD_PARTY_NOTICES.md"
  simplifile.write(to: path, contents: render_overview(components))
  |> result.map_error(describe(path, _))
}

fn read(path: String) -> Result(String, String) {
  simplifile.read(path) |> result.map_error(describe(path, _))
}

fn describe(path: String, error: simplifile.FileError) -> String {
  path <> ": " <> simplifile.describe_error(error)
}

@external(erlang, "erlang", "halt")
fn halt(status: Int) -> Nil

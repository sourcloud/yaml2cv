//// Generates third-party license notices for the packages in an Erlang
//// shipment (ADR 0013). Dev-only; run from the project root after
//// `gleam export erlang-shipment`:
////
////     gleam run -m notices -- build/erlang-shipment <output directory>
////
//// Writes `<output>/THIRD_PARTY_NOTICES.md` and `<output>/licenses/<package>/`.

import argv
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import simplifile
import tom

/// A dependency as locked in `manifest.toml`.
pub type Package {
  Package(name: String, version: String, otp_app: String)
}

pub type LicenseFile {
  LicenseFile(name: String, content: String)
}

pub type Notice {
  Notice(
    package: String,
    version: String,
    licenses: List(String),
    files: List(LicenseFile),
  )
}

/// The application itself; it needs no third-party notice.
const own_app = "yaml2cv"

pub fn main() -> Nil {
  case argv.load().arguments {
    [shipment, output] ->
      case run(shipment, output) {
        Ok(count) ->
          io.println(
            "Wrote notices for " <> string.inspect(count) <> " packages",
          )
        Error(error) -> {
          io.println_error("error: " <> error)
          halt(1)
        }
      }
    _ -> {
      io.println_error("usage: gleam run -m notices -- <shipment> <output>")
      halt(1)
    }
  }
}

fn run(shipment: String, output: String) -> Result(Int, String) {
  use manifest <- result.try(read("manifest.toml"))
  use packages <- result.try(parse_manifest(manifest))
  use apache <- result.try(read("LICENSE"))
  use entries <- result.try(
    simplifile.read_directory(shipment)
    |> result.map_error(describe(shipment, _)),
  )
  let apps =
    entries
    |> list.filter(fn(entry) {
      entry != own_app
      && simplifile.is_directory(shipment <> "/" <> entry) == Ok(True)
    })
  use notices <- result.try(list.try_map(apps, notice_for(_, packages, apache)))
  let notices =
    list.sort(notices, fn(a, b) { string.compare(a.package, b.package) })
  use _ <- result.try(write_notices(notices, output))
  Ok(list.length(notices))
}

fn notice_for(
  app: String,
  packages: List(Package),
  apache: String,
) -> Result(Notice, String) {
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
  Ok(Notice(package: package.name, version: package.version, licenses:, files:))
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
    |> result.map(fn(content) { LicenseFile(name:, content:) })
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
    [], ["Apache-2.0"] -> Ok([LicenseFile(name: "LICENSE", content: apache)])
    [], _ ->
      Error(
        package
        <> ": no license file shipped and no standard text for "
        <> string.join(licenses, ", "),
      )
  }
}

/// The Markdown overview listing every package and its license files.
pub fn render_overview(notices: List(Notice)) -> String {
  let rows =
    list.map(notices, fn(notice) {
      let licenses = case notice.licenses {
        [] -> "see license file"
        licenses -> string.join(licenses, ", ")
      }
      let files =
        notice.files
        |> list.map(fn(file) {
          "`licenses/" <> notice.package <> "/" <> file.name <> "`"
        })
        |> string.join(", ")
      "| "
      <> notice.package
      <> " | "
      <> notice.version
      <> " | "
      <> licenses
      <> " | "
      <> files
      <> " |"
    })
  string.join(
    [
      "# Third-party notices",
      "",
      "yaml2cv includes the following third-party packages. Their license texts",
      "are in the `licenses/` directory next to this file. The container image",
      "also contains Erlang/OTP and Typst; see `licenses/erlang-otp/` and",
      "`licenses/typst/`.",
      "",
      "| Package | Version | License | Files |",
      "| --- | --- | --- | --- |",
      ..rows
    ],
    "\n",
  )
  <> "\n"
}

fn write_notices(notices: List(Notice), output: String) -> Result(Nil, String) {
  use _ <- result.try(
    list.try_each(notices, fn(notice) {
      let directory = output <> "/licenses/" <> notice.package
      use _ <- result.try(
        simplifile.create_directory_all(directory)
        |> result.map_error(describe(directory, _)),
      )
      list.try_each(notice.files, fn(file) {
        let path = directory <> "/" <> file.name
        simplifile.write(to: path, contents: file.content)
        |> result.map_error(describe(path, _))
      })
    }),
  )
  let path = output <> "/THIRD_PARTY_NOTICES.md"
  simplifile.write(to: path, contents: render_overview(notices))
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

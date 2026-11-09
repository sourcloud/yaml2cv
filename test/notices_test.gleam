import birdie
import gleam/option.{None, Some}
import notices.{Arguments, Declared, Package}
import yaml2cv/notices.{Component, LicenseFile} as _

const manifest =
  "
packages = [
  { name = \"gleam_stdlib\", version = \"1.0.0\", build_tools = [\"gleam\"], requirements = [], otp_app = \"gleam_stdlib\", source = \"hex\", outer_checksum = \"AA\" },
  { name = \"hpack_erl\", version = \"0.3.0\", build_tools = [\"rebar3\"], requirements = [], otp_app = \"hpack\", source = \"hex\", outer_checksum = \"BB\" },
]

[requirements]
gleam_stdlib = { version = \">= 1.0.0 and < 2.0.0\" }
"

pub fn parses_packages_from_manifest_test() {
  assert notices.parse_manifest(manifest)
    == Ok([
      Package(name: "gleam_stdlib", version: "1.0.0", otp_app: "gleam_stdlib"),
      Package(name: "hpack_erl", version: "0.3.0", otp_app: "hpack"),
    ])
}

pub fn reads_licences_from_gleam_toml_test() {
  assert notices.declared_licenses(
      "name = \"envoy\"\nlicences = [\"Apache-2.0\"]\n",
    )
    == ["Apache-2.0"]
}

pub fn reads_licenses_from_app_src_test() {
  assert notices.declared_licenses(
      "{application,hpack,\n [{vsn,\"0.3.0\"},\n  {licenses,[\"MIT\"]},\n  {links,[]}]}.",
    )
    == ["MIT"]
}

pub fn finds_no_licenses_in_unrelated_text_test() {
  assert notices.declared_licenses("nothing here") == []
}

pub fn keeps_shipped_license_files_test() {
  let files = [LicenseFile(name: "LICENSE", text: "MIT text")]
  assert notices.license_texts("pkg", ["MIT"], files, apache: "APACHE")
    == Ok(files)
}

pub fn falls_back_to_apache_text_test() {
  assert notices.license_texts("envoy", ["Apache-2.0"], [], apache: "APACHE")
    == Ok([LicenseFile(name: "LICENSE", text: "APACHE")])
}

pub fn fails_without_any_license_text_test() {
  assert notices.license_texts("odd", ["MIT"], [], apache: "APACHE")
    == Error("odd: no license file shipped and no standard text for MIT")
}

pub fn parses_declared_components_test() {
  let source =
    "
[[component]]
name = \"Inter\"
version = \"4.1\"
licenses = [\"OFL-1.1\"]
files = [\"priv/fonts/inter/OFL.txt\"]

[[component]]
name = \"htmx\"
version = \"2.0.4\"
licenses = [\"0BSD\"]
files = [\"priv/static/vendor/htmx-2.0.4.LICENSE\"]
"
  assert notices.parse_components(source)
    == Ok([
      Declared(name: "Inter", version: "4.1", licenses: ["OFL-1.1"], files: [
        "priv/fonts/inter/OFL.txt",
      ]),
      Declared(name: "htmx", version: "2.0.4", licenses: ["0BSD"], files: [
        "priv/static/vendor/htmx-2.0.4.LICENSE",
      ]),
    ])
}

pub fn rejects_component_without_files_test() {
  let source = "[[component]]\nname = \"x\"\nversion = \"1\"\nlicenses = []\n"
  let assert Error(_) = notices.parse_components(source)
}

pub fn parses_component_flag_test() {
  assert notices.parse_component(
      "Typst|0.15.1|Apache-2.0|/typst/LICENSE,/typst/NOTICE",
    )
    == Ok(
      Declared(
        name: "Typst",
        version: "0.15.1",
        licenses: ["Apache-2.0"],
        files: ["/typst/LICENSE", "/typst/NOTICE"],
      ),
    )
  let assert Error(_) = notices.parse_component("Typst|0.15.1")
  let assert Error(_) = notices.parse_component("Typst|0.15.1|Apache-2.0|")
}

pub fn parses_arguments_test() {
  assert notices.parse_arguments([
      "shipment", "out", "--components", "third_party.toml", "--component",
      "Typst|1|MIT|LICENSE", "--json", "notices.json",
    ])
    == Ok(Arguments(
      shipment: "shipment",
      output: "out",
      component_files: ["third_party.toml"],
      components: ["Typst|1|MIT|LICENSE"],
      json: Some("notices.json"),
    ))
  assert notices.parse_arguments(["shipment", "out"])
    == Ok(Arguments(
      shipment: "shipment",
      output: "out",
      component_files: [],
      components: [],
      json: None,
    ))
  let assert Error(_) = notices.parse_arguments(["shipment"])
  let assert Error(_) = notices.parse_arguments(["s", "o", "--json"])
  let assert Error(_) = notices.parse_arguments(["s", "o", "--bogus", "x"])
}

pub fn renders_notices_overview_test() {
  notices.render_overview([
    Component(name: "envoy", version: "1.0.2", licenses: ["Apache-2.0"], files: [
      LicenseFile(name: "LICENSE", text: "APACHE"),
    ]),
    Component(
      name: "Erlang/OTP",
      version: "29.1.2",
      licenses: ["Apache-2.0"],
      files: [
        LicenseFile(name: "LICENSE", text: "APACHE"),
      ],
    ),
    Component(name: "hpack_erl", version: "0.3.0", licenses: [], files: [
      LicenseFile(name: "LICENSE", text: "MIT"),
    ]),
  ])
  |> birdie.snap(title: "third party notices overview")
}

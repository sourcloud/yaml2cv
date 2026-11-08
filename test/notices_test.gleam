import birdie
import notices.{LicenseFile, Notice, Package}

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
  let files = [LicenseFile(name: "LICENSE", content: "MIT text")]
  assert notices.license_texts("pkg", ["MIT"], files, apache: "APACHE")
    == Ok(files)
}

pub fn falls_back_to_apache_text_test() {
  assert notices.license_texts("envoy", ["Apache-2.0"], [], apache: "APACHE")
    == Ok([LicenseFile(name: "LICENSE", content: "APACHE")])
}

pub fn fails_without_any_license_text_test() {
  assert notices.license_texts("odd", ["MIT"], [], apache: "APACHE")
    == Error("odd: no license file shipped and no standard text for MIT")
}

pub fn renders_notices_overview_test() {
  notices.render_overview([
    Notice(package: "envoy", version: "1.0.2", licenses: ["Apache-2.0"], files: [
      LicenseFile(name: "LICENSE", content: "APACHE"),
    ]),
    Notice(package: "hpack_erl", version: "0.3.0", licenses: [], files: [
      LicenseFile(name: "LICENSE", content: "MIT"),
    ]),
  ])
  |> birdie.snap(title: "third party notices overview")
}

import simplifile
import yaml2cv/notices.{Component, LicenseFile}

const inter =
  Component(
    name: "Inter",
    version: "4.1",
    licenses: ["OFL-1.1"],
    files: [LicenseFile(name: "OFL.txt", text: "Copyright \"Inter\"\n")],
  )

pub fn round_trips_through_json_test() {
  let components = [
    inter,
    Component(name: "hpack_erl", version: "0.3.0", licenses: [], files: []),
  ]
  assert notices.from_json(notices.to_json(components)) == Ok(components)
}

pub fn rejects_invalid_json_test() {
  let assert Error(_) = notices.from_json("{\"components\": 1}")
}

pub fn missing_file_means_no_notices_test() {
  assert notices.load("test/fixtures/does-not-exist.json") == Ok([])
}

pub fn loads_notices_from_file_test() {
  let path = "build/notices_test.json"
  let assert Ok(_) = simplifile.write(path, notices.to_json([inter]))
  assert notices.load(path) == Ok([inter])
}

pub fn invalid_file_is_an_error_test() {
  let path = "build/notices_test_invalid.json"
  let assert Ok(_) = simplifile.write(path, "nope")
  let assert Error("build/notices_test_invalid.json: invalid notices JSON") =
    notices.load(path)
}

pub fn slugs_component_names_test() {
  assert notices.slug("Erlang/OTP") == "erlang-otp"
  assert notices.slug("hpack_erl") == "hpack_erl"
  assert notices.slug("Inter") == "inter"
  assert notices.slug("gleam.json") == "gleam.json"
}

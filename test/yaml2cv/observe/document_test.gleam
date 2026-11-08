import birdie
import gleam/dict
import gleam/json
import gleam/option.{None, Some}
import gleam/string
import yaml2cv/config
import yaml2cv/observe/document
import yaml2cv/observe/network.{Interface}
import yaml2cv/observe/system.{Status}

fn document() -> document.Document {
  let assert Ok(config) =
    config.parse(
      dict.from_list([
        #("BIND_ADDRESS", "::"),
        #("ADMIN_BIND_ADDRESS", "0.0.0.0"),
        #("PHONE_HOME_TARGET", "collector.local:5140"),
        #("REQUIRES", "collector"),
        #("GIT_REVISION", "585b6be"),
        #("BUILD_DATE", "2026-11-07T21:00:00Z"),
        #("DEPLOYED_BY", "Jane Roe"),
      ]),
      schedulers: 4,
      priv_directory: "/app/priv",
      version: "0.3.0",
    )
  document.build(
    config,
    interfaces: [
      Interface(name: "eth0", ipv4: ["10.0.0.135"], ipv6: ["fd00::87"]),
    ],
    status: Status(
      memory: Some(41),
      cpu_load: Some(#(0.4, 0.3, 0.2)),
      io_load: Some(0.1),
      disk: None,
    ),
  )
}

pub fn encodes_full_document_test() {
  document()
  |> document.to_json
  |> json.to_string
  |> birdie.snap(title: "observe full document")
}

pub fn encodes_compact_heartbeat_test() {
  let heartbeat = document() |> document.heartbeat_json |> json.to_string
  assert string.byte_size(heartbeat) < 1200
  birdie.snap(heartbeat, title: "observe heartbeat")
}

pub fn heartbeat_links_use_ipv6_when_there_is_no_ipv4_test() {
  let document =
    document.Document(
      ..document(),
      address: document.Address(
        ..document().address,
        host: None,
        ipv6: Some("fd00::87"),
      ),
    )
  let heartbeat = document |> document.heartbeat_json |> json.to_string
  assert string.contains(heartbeat, "\"self\":\"http://[fd00::87]:9000/\"")
}

pub fn heartbeat_links_use_specific_admin_bind_address_test() {
  let document = document.Document(..document(), admin_host: "10.8.0.2")
  let heartbeat = document |> document.heartbeat_json |> json.to_string
  assert string.contains(heartbeat, "\"self\":\"http://10.8.0.2:9000/\"")
}

//// The observability document served by the admin listener and, in compact
//// form, sent as UDP heartbeat (ADR 0020).

import gleam/int
import gleam/json.{type Json}
import gleam/list
import gleam/option.{type Option, Some}
import gleam/result
import gleam/string
import yaml2cv/config.{type Config, type Metadata}
import yaml2cv/observe/network.{type Interface}
import yaml2cv/observe/system.{type Status}

pub type Document {
  Document(
    name: String,
    version: String,
    requires: List(String),
    address: Address,
    heartbeat: Heartbeat,
    metadata: Metadata,
    /// The effective configuration, as name/value pairs.
    settings: List(#(String, Json)),
    status: Status,
    /// The address the admin listener is bound to; heartbeat links use it
    /// unless it is a wildcard.
    admin_host: String,
  )
}

/// Where the instance can be reached.
pub type Address {
  Address(
    /// First reachable IPv4 address.
    host: Option(String),
    port: Int,
    admin_port: Int,
    /// First reachable IPv6 address.
    ipv6: Option(String),
    interfaces: List(Interface),
  )
}

pub type Heartbeat {
  Heartbeat(interval: Int, mia_interval: Int)
}

/// Paths on the admin listener, by relation name.
pub const rel = [
  #("self", "/"),
  #("config", "/config"),
  #("status", "/status"),
  #("health", "/healthz"),
]

/// Assembles the document from the configuration, the interfaces the public
/// listener is reachable on and a status sample.
pub fn build(
  config: Config,
  interfaces interfaces: List(Interface),
  status status: Status,
) -> Document {
  let phone_home = config.phone_home
  Document(
    name: "yaml2cv",
    version: config.version,
    requires: phone_home.requires,
    address: Address(
      host: network.first_ipv4(interfaces) |> option.from_result,
      port: config.port,
      admin_port: config.admin.port,
      ipv6: network.first_ipv6(interfaces) |> option.from_result,
      interfaces:,
    ),
    heartbeat: Heartbeat(
      interval: phone_home.interval,
      mia_interval: phone_home.mia_interval,
    ),
    metadata: phone_home.metadata,
    settings: settings(config),
    status:,
    admin_host: config.admin.bind_address,
  )
}

fn settings(config: Config) -> List(#(String, Json)) {
  let target =
    option.map(config.phone_home.target, fn(target) {
      target.host <> ":" <> int.to_string(target.port)
    })
  [
    #("port", json.int(config.port)),
    #("bind_address", json.string(config.bind_address)),
    #("max_body_bytes", json.int(config.max_body_bytes)),
    #("render_concurrency", json.int(config.render_concurrency)),
    #("render_queue_wait_ms", json.int(config.render_queue_wait)),
    #("render_timeout_ms", json.int(config.typst.timeout)),
    #("typst_path", json.string(config.typst.executable)),
    #("work_dir", json.string(config.typst.work_directory)),
    #("admin_bind_address", json.string(config.admin.bind_address)),
    #("admin_port", json.int(config.admin.port)),
    #("phone_home_target", json.nullable(target, json.string)),
    #("heartbeat_interval_ms", json.int(config.phone_home.interval)),
    #("heartbeat_mia_ms", json.int(config.phone_home.mia_interval)),
  ]
}

/// The full document.
pub fn to_json(document: Document) -> Json {
  json.object([
    #("name", json.string(document.name)),
    #("version", json.string(document.version)),
    #("requires", json.array(document.requires, json.string)),
    #("address", address_json(document.address, with_interfaces: True)),
    #("heartbeat", heartbeat_member(document.heartbeat)),
    #("config", config_json(document)),
    #("status", status_json(document.status)),
    #("rel", rel_json(fn(path) { path })),
  ])
}

/// The `config` member: build and deployment metadata plus settings.
pub fn config_json(document: Document) -> Json {
  let metadata = document.metadata
  json.object([
    #("git_revision", json.nullable(metadata.git_revision, json.string)),
    #("build_date", json.nullable(metadata.build_date, json.string)),
    #("deployed_from", json.nullable(metadata.deployed_from, json.string)),
    #("deployed_by", json.nullable(metadata.deployed_by, json.string)),
    #("deployed_on", json.nullable(metadata.deployed_on, json.string)),
    #("settings", json.object(document.settings)),
  ])
}

/// The `status` member.
pub fn status_json(status: Status) -> Json {
  json.object([
    #("memory", json.nullable(status.memory, json.int)),
    #(
      "cpu_load",
      json.nullable(status.cpu_load, fn(load) {
        json.preprocessed_array([
          json.float(load.0),
          json.float(load.1),
          json.float(load.2),
        ])
      }),
    ),
    #("io_load", json.nullable(status.io_load, json.float)),
    #("disk", json.nullable(status.disk, json.int)),
  ])
}

/// The compact heartbeat: no interfaces or configuration, and `rel` as
/// absolute URLs of the admin listener so a collector can follow them.
pub fn heartbeat_json(document: Document) -> Json {
  let base = case document.admin_host, document.address {
    "0.0.0.0", Address(host: Some(host), ..)
    | "::", Address(host: Some(host), ..)
    -> Ok(host)
    "0.0.0.0", Address(ipv6: Some(ipv6), ..)
    | "::", Address(ipv6: Some(ipv6), ..)
    -> Ok("[" <> ipv6 <> "]")
    "0.0.0.0", _ | "::", _ -> Error(Nil)
    admin_host, _ ->
      case string.contains(admin_host, ":") {
        True -> Ok("[" <> admin_host <> "]")
        False -> Ok(admin_host)
      }
  }
  let url = fn(path) {
    base
    |> result.map(fn(host) {
      "http://"
      <> host
      <> ":"
      <> int.to_string(document.address.admin_port)
      <> path
    })
    |> result.unwrap(path)
  }
  json.object([
    #("name", json.string(document.name)),
    #("version", json.string(document.version)),
    #("address", address_json(document.address, with_interfaces: False)),
    #("heartbeat", heartbeat_member(document.heartbeat)),
    #("status", status_json(document.status)),
    #("rel", rel_json(url)),
  ])
}

fn address_json(
  address: Address,
  with_interfaces with_interfaces: Bool,
) -> Json {
  let members = [
    #("host", json.nullable(address.host, json.string)),
    #("port", json.string(int.to_string(address.port))),
    #("admin_port", json.string(int.to_string(address.admin_port))),
    #("ipv6", json.nullable(address.ipv6, json.string)),
  ]
  case with_interfaces {
    True ->
      json.object(
        list.append(members, [
          #("interfaces", json.array(address.interfaces, interface_json)),
        ]),
      )
    False -> json.object(members)
  }
}

fn interface_json(interface: Interface) -> Json {
  json.object([
    #("name", json.string(interface.name)),
    #("ipv4", json.array(interface.ipv4, json.string)),
    #("ipv6", json.array(interface.ipv6, json.string)),
  ])
}

fn heartbeat_member(heartbeat: Heartbeat) -> Json {
  json.object([
    #("interval", json.int(heartbeat.interval)),
    #("mia_interval", json.int(heartbeat.mia_interval)),
  ])
}

fn rel_json(url: fn(String) -> String) -> Json {
  json.object(
    list.map(rel, fn(link) {
      let #(name, path) = link
      #(name, json.string(url(path)))
    }),
  )
}

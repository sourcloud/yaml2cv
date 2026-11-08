//// Network interfaces the public listener is reachable on (ADR 0020).

import gleam/list
import gleam/string

/// An interface as reported by the operating system.
pub type RawInterface {
  RawInterface(name: String, up: Bool, addresses: List(String))
}

/// An interface with the addresses the service is reachable on.
pub type Interface {
  Interface(name: String, ipv4: List(String), ipv6: List(String))
}

/// The interfaces of this host, with their addresses in textual form.
@external(erlang, "yaml2cv_network_ffi", "interfaces")
pub fn interfaces() -> List(RawInterface)

/// Keeps the interfaces and addresses a listener bound to `bind` accepts
/// connections on. A wildcard bind (`0.0.0.0` for IPv4, `::` for both
/// families) reaches every address of its families except loopback and
/// link-local ones; any other bind reaches only that address.
pub fn reachable(
  interfaces: List(RawInterface),
  bind bind: String,
) -> List(Interface) {
  interfaces
  |> list.filter(fn(interface) { interface.up })
  |> list.filter_map(fn(interface) {
    let addresses = list.filter(interface.addresses, accepts(bind, _))
    case addresses {
      [] -> Error(Nil)
      _ ->
        Ok(Interface(
          name: interface.name,
          ipv4: list.filter(addresses, fn(address) { !is_ipv6(address) }),
          ipv6: list.filter(addresses, is_ipv6),
        ))
    }
  })
}

/// The first IPv4 address of the given interfaces.
pub fn first_ipv4(interfaces: List(Interface)) -> Result(String, Nil) {
  interfaces |> list.flat_map(fn(interface) { interface.ipv4 }) |> list.first
}

/// The first IPv6 address of the given interfaces.
pub fn first_ipv6(interfaces: List(Interface)) -> Result(String, Nil) {
  interfaces |> list.flat_map(fn(interface) { interface.ipv6 }) |> list.first
}

fn accepts(bind: String, address: String) -> Bool {
  case bind {
    "0.0.0.0" -> !is_ipv6(address) && routable(address)
    "::" -> routable(address)
    _ -> string.lowercase(bind) == string.lowercase(address)
  }
}

fn is_ipv6(address: String) -> Bool {
  string.contains(address, ":")
}

fn routable(address: String) -> Bool {
  let address = string.lowercase(address)
  !{
    string.starts_with(address, "127.")
    || string.starts_with(address, "169.254.")
    || address == "::1"
    || string.starts_with(address, "fe80:")
  }
}

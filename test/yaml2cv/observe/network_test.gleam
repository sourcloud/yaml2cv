import yaml2cv/observe/network.{Interface, RawInterface}

const interfaces = [
  RawInterface(name: "lo", up: True, addresses: ["127.0.0.1", "::1"]),
  RawInterface(
    name: "eth0",
    up: True,
    addresses: ["10.0.0.135", "fe80::1", "fd00::87"],
  ),
  RawInterface(name: "eth1", up: True, addresses: ["169.254.3.4"]),
  RawInterface(name: "eth2", up: False, addresses: ["192.168.1.2"]),
  RawInterface(name: "wg0", up: True, addresses: ["10.8.0.2"]),
]

pub fn ipv4_wildcard_reaches_routable_ipv4_addresses_test() {
  assert network.reachable(interfaces, bind: "0.0.0.0")
    == [
      Interface(name: "eth0", ipv4: ["10.0.0.135"], ipv6: []),
      Interface(name: "wg0", ipv4: ["10.8.0.2"], ipv6: []),
    ]
}

pub fn ipv6_wildcard_reaches_both_families_test() {
  assert network.reachable(interfaces, bind: "::")
    == [
      Interface(name: "eth0", ipv4: ["10.0.0.135"], ipv6: ["fd00::87"]),
      Interface(name: "wg0", ipv4: ["10.8.0.2"], ipv6: []),
    ]
}

pub fn specific_address_reaches_only_itself_test() {
  assert network.reachable(interfaces, bind: "127.0.0.1")
    == [Interface(name: "lo", ipv4: ["127.0.0.1"], ipv6: [])]
  assert network.reachable(interfaces, bind: "fd00::87")
    == [Interface(name: "eth0", ipv4: [], ipv6: ["fd00::87"])]
  assert network.reachable(interfaces, bind: "192.168.1.2") == []
}

pub fn picks_first_address_of_each_family_test() {
  let reachable = network.reachable(interfaces, bind: "::")
  assert network.first_ipv4(reachable) == Ok("10.0.0.135")
  assert network.first_ipv6(reachable) == Ok("fd00::87")
  assert network.first_ipv6([]) == Error(Nil)
}

pub fn lists_interfaces_of_this_host_test() {
  let assert [_, ..] = network.interfaces()
}

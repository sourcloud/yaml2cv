import gleam/erlang/process
import yaml2cv/observe/heartbeat

pub fn sends_payload_every_interval_test() {
  let beats = process.new_subject()
  let assert Ok(_) =
    heartbeat.start(
      interval: 20,
      payload: fn() { <<"beat">> },
      send: fn(packet) {
        process.send(beats, packet)
        Ok(Nil)
      },
    )
  assert process.receive(beats, 200) == Ok(<<"beat">>)
  assert process.receive(beats, 200) == Ok(<<"beat">>)
}

pub fn keeps_beating_after_send_errors_test() {
  let attempts = process.new_subject()
  let assert Ok(_) =
    heartbeat.start(interval: 20, payload: fn() { <<"beat">> }, send: fn(_) {
      process.send(attempts, Nil)
      Error("network unreachable")
    })
  assert process.receive(attempts, 200) == Ok(Nil)
  assert process.receive(attempts, 200) == Ok(Nil)
}

pub fn sends_udp_datagram_test() {
  let #(socket, port) = open_receiver()
  assert heartbeat.send_udp("127.0.0.1", port, <<"hello">>) == Ok(Nil)
  assert receive(socket, 1000) == Ok(<<"hello">>)
}

pub fn reports_unresolvable_host_test() {
  let assert Error(_) =
    heartbeat.send_udp("no-such-host.invalid", 5140, <<"hello">>)
}

type Socket

@external(erlang, "yaml2cv_udp_test_ffi", "open_receiver")
fn open_receiver() -> #(Socket, Int)

@external(erlang, "yaml2cv_udp_test_ffi", "receive")
fn receive(socket: Socket, timeout: Int) -> Result(BitArray, Nil)

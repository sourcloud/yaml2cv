//// Periodic UDP heartbeat to a collector (ADR 0020).

import gleam/erlang/process
import gleam/otp/actor
import gleam/otp/supervision
import gleam/result
import wisp

pub opaque type Message {
  Beat
}

/// Starts a process that calls `send` with a fresh `payload` right away and
/// then every `interval` milliseconds. Send errors are logged; they never
/// stop the heartbeat.
pub fn start(
  interval interval: Int,
  payload payload: fn() -> BitArray,
  send send: fn(BitArray) -> Result(Nil, String),
) -> Result(actor.Started(Nil), actor.StartError) {
  actor.new_with_initialiser(1000, fn(subject) {
    process.send(subject, Beat)
    actor.initialised(subject)
    |> Ok
  })
  |> actor.on_message(fn(subject, _message: Message) {
    case send(payload()) {
      Ok(Nil) -> Nil
      Error(reason) -> wisp.log_warning("heartbeat not sent: " <> reason)
    }
    process.send_after(subject, interval, Beat)
    actor.continue(subject)
  })
  |> actor.start
  |> result.map(fn(started) { actor.Started(..started, data: Nil) })
}

/// A child specification for `start`, for use in a supervision tree.
pub fn supervised(
  interval interval: Int,
  payload payload: fn() -> BitArray,
  send send: fn(BitArray) -> Result(Nil, String),
) -> supervision.ChildSpecification(Nil) {
  supervision.worker(fn() { start(interval:, payload:, send:) })
}

/// Sends one datagram to `host` (name or IPv4/IPv6 address) and `port`.
@external(erlang, "yaml2cv_udp_ffi", "send")
pub fn send_udp(
  host: String,
  port: Int,
  packet: BitArray,
) -> Result(Nil, String)

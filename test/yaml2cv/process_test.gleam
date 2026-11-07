import gleam/order
import gleam/time/duration
import gleam/time/timestamp
import yaml2cv/process.{ExecutableNotFound, Exit, TimedOut}

pub fn returns_exit_status_and_output_test() {
  assert process.run(
      "sh",
      ["-c", "echo out; echo err >&2"],
      in: ".",
      timeout: 5000,
    )
    == Ok(Exit(status: 0, output: "out\nerr\n"))
}

pub fn returns_non_zero_exit_status_test() {
  assert process.run("sh", ["-c", "exit 3"], in: ".", timeout: 5000)
    == Ok(Exit(status: 3, output: ""))
}

pub fn runs_in_given_directory_test() {
  assert process.run("pwd", [], in: "/", timeout: 5000)
    == Ok(Exit(status: 0, output: "/\n"))
}

pub fn times_out_long_running_command_test() {
  let started = timestamp.system_time()
  assert process.run("sleep", ["5"], in: ".", timeout: 100) == Error(TimedOut)
  let elapsed = timestamp.difference(started, timestamp.system_time())
  assert duration.compare(elapsed, duration.seconds(1)) == order.Lt
}

pub fn reports_missing_executable_test() {
  assert process.run("yaml2cv-does-not-exist", [], in: ".", timeout: 1000)
    == Error(ExecutableNotFound("yaml2cv-does-not-exist"))
}

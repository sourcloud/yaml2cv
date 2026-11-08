//// System status for the observability document (ADR 0020): memory, load,
//// I/O pressure and disk use, read from Linux `/proc`, `/sys/fs/cgroup` and
//// `df`. Values that cannot be read are `None`.

import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import simplifile
import yaml2cv/process.{Exit}

pub type Status {
  Status(
    /// Percent of memory in use: of the cgroup limit if set, else the host.
    memory: Option(Int),
    /// Load averages over 1, 5 and 15 minutes.
    cpu_load: Option(#(Float, Float, Float)),
    /// Percent of time tasks stalled on I/O over the last 10 seconds.
    io_load: Option(Float),
    /// Percent used of the file system holding the work directory.
    disk: Option(Int),
  )
}

/// Reads the current status; `work_directory` selects the file system
/// reported as `disk`.
pub fn sample(work_directory: String) -> Status {
  Status(
    memory: memory() |> option.from_result,
    cpu_load: read("/proc/loadavg", parse_loadavg) |> option.from_result,
    io_load: read("/proc/pressure/io", parse_pressure) |> option.from_result,
    disk: disk(work_directory) |> option.from_result,
  )
}

fn memory() -> Result(Int, Nil) {
  let cgroup = {
    use current <- result.try(read_file("/sys/fs/cgroup/memory.current"))
    use limit <- result.try(read_file("/sys/fs/cgroup/memory.max"))
    cgroup_memory(current, limit)
  }
  result.lazy_or(cgroup, fn() { read("/proc/meminfo", parse_meminfo) })
}

fn disk(work_directory: String) -> Result(Int, Nil) {
  let directory = existing_ancestor(work_directory)
  case process.run("df", ["-P", directory], in: ".", timeout: 2000) {
    Ok(Exit(status: 0, output:)) -> parse_df(output)
    _ -> Error(Nil)
  }
}

/// The work directory is created on the first render; until then report the
/// file system of its closest existing ancestor.
fn existing_ancestor(path: String) -> String {
  case simplifile.is_directory(path) {
    Ok(True) -> path
    _ ->
      case string.split(path, "/") |> list.reverse {
        [_, ..rest] if rest != [] && rest != [""] ->
          existing_ancestor(rest |> list.reverse |> string.join("/"))
        _ -> "/"
      }
  }
}

fn read(path: String, parse: fn(String) -> Result(a, Nil)) -> Result(a, Nil) {
  read_file(path) |> result.try(parse)
}

fn read_file(path: String) -> Result(String, Nil) {
  simplifile.read(path) |> result.replace_error(Nil)
}

/// Parses `/proc/loadavg` into the 1, 5 and 15 minute load averages.
pub fn parse_loadavg(text: String) -> Result(#(Float, Float, Float), Nil) {
  case string.split(string.trim(text), " ") {
    [one, five, fifteen, ..] -> {
      use one <- result.try(float.parse(one))
      use five <- result.try(float.parse(five))
      use fifteen <- result.try(float.parse(fifteen))
      Ok(#(one, five, fifteen))
    }
    _ -> Error(Nil)
  }
}

/// Percent of host memory in use, from `/proc/meminfo`.
pub fn parse_meminfo(text: String) -> Result(Int, Nil) {
  let fields =
    string.split(text, "\n")
    |> list.filter_map(fn(line) {
      use #(key, value) <- result.try(string.split_once(line, ":"))
      let value = string.trim(value) |> string.replace(" kB", "")
      use value <- result.map(int.parse(value))
      #(key, value)
    })
  use total <- result.try(list.key_find(fields, "MemTotal"))
  use available <- result.try(list.key_find(fields, "MemAvailable"))
  percent(total - available, of: total)
}

/// Percent of the cgroup memory limit in use, from the contents of
/// `memory.current` and `memory.max`; `Error` when no limit is set.
pub fn cgroup_memory(current: String, limit: String) -> Result(Int, Nil) {
  use current <- result.try(int.parse(string.trim(current)))
  use limit <- result.try(int.parse(string.trim(limit)))
  percent(current, of: limit)
}

/// The `some avg10` value of a pressure stall information file.
pub fn parse_pressure(text: String) -> Result(Float, Nil) {
  string.split(text, "\n")
  |> list.find_map(fn(line) {
    case string.split(line, " ") {
      ["some", "avg10=" <> value, ..] -> float.parse(value)
      _ -> Error(Nil)
    }
  })
}

/// Percent used from the output of `df -P <path>`.
pub fn parse_df(text: String) -> Result(Int, Nil) {
  case string.split(string.trim(text), "\n") {
    [_header, line, ..] ->
      line
      |> string.split(" ")
      |> list.filter(fn(field) { field != "" })
      |> list.find_map(fn(field) {
        case string.ends_with(field, "%") {
          True -> int.parse(string.drop_end(field, 1))
          False -> Error(Nil)
        }
      })
    _ -> Error(Nil)
  }
}

fn percent(part: Int, of whole: Int) -> Result(Int, Nil) {
  case whole > 0 {
    True -> Ok(float.round(int.to_float(part) *. 100.0 /. int.to_float(whole)))
    False -> Error(Nil)
  }
}

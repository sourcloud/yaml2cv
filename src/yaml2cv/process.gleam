//// Runs external programs through Erlang ports, with a hard timeout.

/// How a finished program exited. `output` holds stdout and stderr combined.
pub type Exit {
  Exit(status: Int, output: String)
}

pub type RunError {
  /// Neither a path nor a name on `PATH` resolved to an executable file.
  ExecutableNotFound(String)
  /// The program ran longer than allowed and was killed.
  TimedOut
}

/// Runs `executable` with `arguments` in directory `in`, killing it after
/// `timeout` milliseconds. Relative executable paths are resolved against the
/// current working directory, not `in`.
@external(erlang, "yaml2cv_process_ffi", "run")
pub fn run(
  executable: String,
  arguments: List(String),
  in directory: String,
  timeout timeout: Int,
) -> Result(Exit, RunError)

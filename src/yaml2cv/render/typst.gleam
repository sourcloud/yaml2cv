//// Renders CVs with the Typst CLI (ADR 0009).

import gleam/int
import gleam/json
import gleam/result
import simplifile
import yaml2cv/cv.{type Cv}
import yaml2cv/cv/encode
import yaml2cv/process.{Exit}
import yaml2cv/render.{
  type RenderError, type Renderer, CompileFailed, Renderer, RendererUnavailable,
}

pub type Config {
  Config(
    /// Name on `PATH` or path of the `typst` executable.
    executable: String,
    /// Directory holding one sub-directory per theme.
    themes_directory: String,
    /// Directory in which a temporary directory per render is created.
    work_directory: String,
    /// Maximum compile time in milliseconds.
    timeout: Int,
  )
}

/// Creates a renderer backed by Typst.
pub fn new(config: Config) -> Renderer {
  Renderer(render: render(config, _))
}

/// Renders a CV to PDF bytes. The temporary job directory is removed
/// afterwards, whatever the outcome.
pub fn render(config: Config, cv: Cv) -> Result(BitArray, RenderError) {
  let job =
    config.work_directory
    <> "/job-"
    <> int.to_string(unique_integer())
    <> "-"
    <> int.to_string(int.random(1_000_000_000))
  let result = {
    use _ <- result.try(prepare(config, job, cv))
    compile(config, job)
  }
  let _ = simplifile.delete(job)
  result
}

fn prepare(config: Config, job: String, cv: Cv) -> Result(Nil, RenderError) {
  let theme = config.themes_directory <> "/" <> cv.theme_name(cv.style.theme)
  {
    use _ <- result.try(simplifile.create_directory_all(job))
    use _ <- result.try(simplifile.copy_directory(at: theme, to: job))
    simplifile.write(
      to: job <> "/cv.json",
      contents: json.to_string(encode.to_json(cv)),
    )
  }
  |> result.map_error(fn(error) {
    RendererUnavailable(
      "could not prepare render job: " <> simplifile.describe_error(error),
    )
  })
}

fn compile(config: Config, job: String) -> Result(BitArray, RenderError) {
  let arguments = [
    "compile", "--root", ".", "--ignore-system-fonts", "cv.typ", "cv.pdf",
  ]
  case
    process.run(config.executable, arguments, in: job, timeout: config.timeout)
  {
    Ok(Exit(status: 0, ..)) ->
      simplifile.read_bits(job <> "/cv.pdf")
      |> result.map_error(fn(error) {
        RendererUnavailable(
          "could not read rendered PDF: " <> simplifile.describe_error(error),
        )
      })
    Ok(Exit(output:, ..)) -> Error(CompileFailed(output))
    Error(process.TimedOut) -> Error(render.TimedOut)
    Error(process.ExecutableNotFound(name)) ->
      Error(RendererUnavailable("typst executable not found: " <> name))
  }
}

@external(erlang, "erlang", "unique_integer")
fn unique_integer() -> Int

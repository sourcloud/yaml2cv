//// Renders CVs with the Typst CLI (ADR 0009).

import gleam/int
import gleam/json
import gleam/list
import gleam/result
import gleam/string
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
    /// Text identifying the producing software; themes write it into the
    /// PDF metadata (ADR 0018).
    generator: String,
  )
}

/// Preview images are rendered for at most this many pages.
pub const max_preview_pages = 10

/// Creates a renderer backed by Typst.
pub fn new(config: Config) -> Renderer {
  Renderer(
    render_pdf: render_pdf(config, _),
    render_svg_pages: render_svg_pages(config, _),
  )
}

/// Renders a CV to PDF bytes.
pub fn render_pdf(config: Config, cv: Cv) -> Result(BitArray, RenderError) {
  use job <- in_job(config, cv, ["cv.pdf"])
  read(job <> "/cv.pdf")
}

/// Renders the first `max_preview_pages` pages of a CV as SVG images.
pub fn render_svg_pages(
  config: Config,
  cv: Cv,
) -> Result(List(BitArray), RenderError) {
  let arguments = [
    "--pages",
    "1-" <> int.to_string(max_preview_pages),
    // Zero-padded page numbers make the file names sort in page order.
    "page-{0p}.svg",
  ]
  use job <- in_job(config, cv, arguments)
  use files <- result.try(
    simplifile.read_directory(job) |> result.map_error(file_error),
  )
  files
  |> list.filter(fn(file) {
    string.starts_with(file, "page-") && string.ends_with(file, ".svg")
  })
  |> list.sort(string.compare)
  |> list.try_map(fn(file) { read(job <> "/" <> file) })
}

/// Prepares a temporary job directory, compiles `cv.typ` in it with the
/// given output arguments and hands the directory to `collect`. The
/// directory is removed afterwards, whatever the outcome.
fn in_job(
  config: Config,
  cv: Cv,
  output_arguments: List(String),
  collect: fn(String) -> Result(a, RenderError),
) -> Result(a, RenderError) {
  let job =
    config.work_directory
    <> "/job-"
    <> int.to_string(unique_integer())
    <> "-"
    <> int.to_string(int.random(1_000_000_000))
  let result = {
    use _ <- result.try(prepare(config, job, cv))
    use _ <- result.try(compile(config, job, output_arguments))
    collect(job)
  }
  let _ = simplifile.delete(job)
  result
}

fn prepare(config: Config, job: String, cv: Cv) -> Result(Nil, RenderError) {
  let theme = config.themes_directory <> "/" <> cv.theme_name(cv.style.theme)
  // CVs are personal data: keep the work and job directories private to the
  // service user. Restricting an existing work directory also fails, rather
  // than writing into it, when it belongs to someone else.
  {
    use _ <- result.try(simplifile.create_directory_all(config.work_directory))
    use _ <- result.try(simplifile.set_permissions_octal(
      config.work_directory,
      0o700,
    ))
    use _ <- result.try(simplifile.create_directory(job))
    use _ <- result.try(simplifile.set_permissions_octal(job, 0o700))
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

fn compile(
  config: Config,
  job: String,
  output_arguments: List(String),
) -> Result(Nil, RenderError) {
  let arguments = [
    "compile",
    "--root",
    ".",
    "--ignore-system-fonts",
    "--input",
    "generator=" <> config.generator,
    "cv.typ",
    ..output_arguments
  ]
  case
    process.run(config.executable, arguments, in: job, timeout: config.timeout)
  {
    Ok(Exit(status: 0, ..)) -> Ok(Nil)
    Ok(Exit(output:, ..)) -> Error(CompileFailed(output))
    Error(process.TimedOut) -> Error(render.TimedOut)
    Error(process.ExecutableNotFound(name)) ->
      Error(RendererUnavailable("typst executable not found: " <> name))
  }
}

fn read(path: String) -> Result(BitArray, RenderError) {
  simplifile.read_bits(path) |> result.map_error(file_error)
}

fn file_error(error: simplifile.FileError) -> RenderError {
  RendererUnavailable(
    "could not read render output: " <> simplifile.describe_error(error),
  )
}

@external(erlang, "erlang", "unique_integer")
fn unique_integer() -> Int

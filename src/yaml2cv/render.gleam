//// The renderer abstraction (ADR 0003): anything that turns a validated CV
//// into PDF bytes.

import yaml2cv/cv.{type Cv}

pub type RenderError {
  /// The backend rejected the document; `output` is its diagnostic output.
  CompileFailed(output: String)
  /// Rendering took longer than allowed and was aborted.
  TimedOut
  /// Too many renders are in progress; try again later.
  Overloaded
  /// The backend cannot run at all, e.g. a missing executable or theme.
  RendererUnavailable(reason: String)
}

/// A rendering backend, expressed as a record of functions so backends can be
/// swapped or wrapped (for example by a concurrency limiter, or a fake in
/// tests).
pub type Renderer {
  Renderer(render: fn(Cv) -> Result(BitArray, RenderError))
}

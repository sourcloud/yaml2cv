//// What this build of yaml2cv is and where its source lives (ADR 0031).
////
//// The revision is self-reported: it helps users find the source and spots
//// builds from modified working trees, but a modified build can claim any
//// revision. Image provenance is checked with GitHub attestations instead.

import gleam/option.{type Option, None, Some}
import gleam/string

/// The project's source repository.
pub const repository = "https://github.com/sourcloud/yaml2cv"

/// Suffix of `GIT_REVISION` for builds from a working tree with changes.
const dirty_suffix = "-dirty"

/// The commit a build claims to come from.
pub type Revision {
  /// Built from this commit without changes.
  Clean(hash: String)
  /// Built from this commit with uncommitted or untracked changes.
  Modified(hash: String)
  /// No revision was recorded, e.g. `gleam run` or a manual image build.
  Unknown
}

/// A release and the commit it was built from.
pub type Build {
  Build(version: String, revision: Revision)
}

/// Reads the `GIT_REVISION` build argument.
pub fn revision(value: Option(String)) -> Revision {
  case option.map(value, string.trim) {
    None | Some("") -> Unknown
    Some(value) ->
      case string.ends_with(value, dirty_suffix) {
        True -> Modified(string.drop_end(value, string.length(dirty_suffix)))
        False -> Clean(value)
      }
  }
}

/// The abbreviated commit hash shown to users.
pub fn short(hash: String) -> String {
  string.slice(hash, at_index: 0, length: 7)
}

/// The commit's page in the source repository.
pub fn commit_url(hash: String) -> String {
  repository <> "/commit/" <> hash
}

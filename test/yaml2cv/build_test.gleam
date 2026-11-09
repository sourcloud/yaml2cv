import gleam/option.{None, Some}
import yaml2cv/build.{Clean, Modified, Unknown}

const hash = "37e695e1c0ffee00000000000000000000000000"

pub fn clean_revision_test() {
  assert build.revision(Some(hash)) == Clean(hash)
}

pub fn dirty_revision_is_modified_test() {
  assert build.revision(Some(hash <> "-dirty")) == Modified(hash)
}

pub fn missing_revision_is_unknown_test() {
  assert build.revision(None) == Unknown
  assert build.revision(Some("")) == Unknown
  assert build.revision(Some("  ")) == Unknown
}

pub fn surrounding_whitespace_is_ignored_test() {
  assert build.revision(Some(" " <> hash <> "\n")) == Clean(hash)
}

pub fn short_hash_test() {
  assert build.short(hash) == "37e695e"
}

pub fn commit_url_test() {
  assert build.commit_url(hash)
    == "https://github.com/sourcloud/yaml2cv/commit/" <> hash
}

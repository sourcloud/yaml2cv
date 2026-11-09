//// The shape of every UI text, one record per locale (ADR 0025). The record
//// constructors make a missing translation a compile error.
////
//// Texts are plain strings. In `SchemaTexts`, parts between backticks are
//// shown as code.

import yaml2cv/cv/decode.{type SchemaProblem}

/// All UI texts of one locale.
pub type Texts {
  Texts(
    ui: UiTexts,
    editor: EditorTexts,
    visual: VisualTexts,
    schema: SchemaTexts,
  )
}

/// Texts of the shell and the shared UI components.
pub type UiTexts {
  UiTexts(
    theme_label: String,
    theme_system: String,
    theme_light: String,
    theme_dark: String,
    language_label: String,
    close: String,
    required_marker: String,
    /// Location shown for errors about the whole document.
    whole_document: String,
    show_in_editor: String,
    page: fn(Int) -> String,
    /// Photo picker (ADR 0028).
    choose_photo: String,
    change_photo: String,
    remove_photo: String,
    photo_failed: String,
    /// Footer (ADR 0031).
    source_code: String,
    modified_build: String,
    revision_unknown: String,
  )
}

/// Texts of the editor page and its fragments.
pub type EditorTexts {
  EditorTexts(
    cv_panel: String,
    edit_mode: String,
    mode_yaml: String,
    mode_visual: String,
    schema_button: String,
    /// The file menu (ADR 0029) and its items.
    file_menu: String,
    copy_yaml: String,
    copied: String,
    copy_failed: String,
    download_yaml: String,
    import_yaml: String,
    /// Takes the largest importable size in KiB.
    import_failed: fn(Int) -> String,
    source_label: String,
    preview_panel: String,
    rendering: String,
    download_pdf: String,
    valid: String,
    problems: fn(Int) -> String,
    visual_needs_fixes: String,
    syntax_hint: String,
    location: fn(Int, Int) -> String,
    schema_problem: fn(SchemaProblem) -> String,
    too_complex: String,
    too_large: fn(Int) -> String,
    preview_unavailable: String,
    download_failed: String,
    busy: String,
    timed_out: String,
    renderer_unavailable: String,
    render_failed: String,
    cannot_create_pdf: String,
    back_to_editor: String,
  )
}

/// Texts of the visual block editor.
pub type VisualTexts {
  VisualTexts(
    rewrite_title: String,
    rewrite_body: String,
    style: String,
    theme: String,
    colour: String,
    paper: String,
    photo_shape: String,
    default_option: fn(String) -> String,
    person: String,
    name: String,
    title: String,
    address: String,
    photo: String,
    contact: String,
    email: String,
    phone: String,
    website: String,
    links: String,
    link: String,
    add_link: String,
    label: String,
    url: String,
    sections: String,
    section: String,
    /// The label of a section kind (`entries`, `skills`, `text`).
    kind: fn(String) -> String,
    /// The title of a section block, given the kind's label.
    section_title: fn(String) -> String,
    /// The add button for a section kind, given the kind's label.
    add_section: String,
    heading: String,
    text: String,
    entries: String,
    entry: String,
    add_entry: String,
    timespan: String,
    organisation: String,
    location: String,
    bullets: String,
    bullet: String,
    add_bullet: String,
    skills: String,
    skill: String,
    add_skill: String,
    level: String,
    remove: String,
    /// Action labels, given a numbered item such as "Link 2".
    move_up: fn(String) -> String,
    move_down: fn(String) -> String,
    remove_item: fn(String) -> String,
  )
}

/// Texts of the schema reference (ADR 0022). Key names and option values
/// are not translated.
pub type SchemaTexts {
  SchemaTexts(
    title: String,
    intro: String,
    key_header: String,
    requirement_header: String,
    description_header: String,
    required: String,
    optional: String,
    if_kind: fn(String) -> String,
    one_of: String,
    default: String,
    document_title: String,
    document_intro: String,
    schema_version: String,
    style_key: String,
    person_key: String,
    contact_key: String,
    sections_key: String,
    style_intro: String,
    theme: String,
    color: String,
    paper: String,
    photo_shape: String,
    person_intro: String,
    person_name: String,
    person_title: String,
    person_address: String,
    person_photo: String,
    contact_intro: String,
    email: String,
    phone: String,
    website: String,
    links: String,
    link_intro: String,
    link_label: String,
    link_url: String,
    section_intro: String,
    section_name: String,
    section_kind: String,
    section_entries: String,
    section_items: String,
    section_text: String,
    entry_intro: String,
    timespan: String,
    entry_title: String,
    organization: String,
    location: String,
    bullets: String,
    skill_intro: String,
    skill_name: String,
    skill_level: String,
  )
}

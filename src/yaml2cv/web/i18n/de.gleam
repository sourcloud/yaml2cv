//// German UI texts (ADR 0025).

import gleam/int
import gleam/string
import yaml2cv/cv/decode.{
  ExpectedInteger, ExpectedList, ExpectedMapping, ExpectedOneDocument,
  ExpectedOneOf, ExpectedText, MustNotBeEmpty, Required, UnknownKey,
  UnsupportedVersion,
}
import yaml2cv/web/i18n/texts.{
  EditorTexts, SchemaTexts, Texts, UiTexts, VisualTexts,
}

/// Every German UI text.
pub fn texts() -> texts.Texts {
  Texts(
    ui: UiTexts(
      theme_label: "Farbschema",
      theme_system: "System",
      theme_light: "Hell",
      theme_dark: "Dunkel",
      language_label: "Sprache",
      close: "Schließen",
      required_marker: " (Pflichtfeld)",
      whole_document: "Dokument",
      show_in_editor: "Im Editor zeigen",
      page: fn(number) { "Seite " <> int.to_string(number) },
    ),
    editor: EditorTexts(
      cv_panel: "Lebenslauf",
      edit_mode: "Bearbeitungsmodus",
      mode_yaml: "YAML",
      mode_visual: "Visuell",
      schema_button: "Schema",
      copy_yaml: "YAML kopieren",
      copied: "Kopiert",
      copy_failed: "Kopieren fehlgeschlagen",
      source_label: "Lebenslauf als YAML",
      preview_panel: "Vorschau",
      rendering: "Wird gesetzt…",
      download_pdf: "PDF herunterladen",
      valid: "Gültiger Lebenslauf",
      problems: fn(count) {
        case count {
          1 -> "1 Problem"
          _ -> int.to_string(count) <> " Probleme"
        }
      },
      visual_needs_fixes: "Für den visuellen Modus zuerst diese Probleme beheben",
      syntax_hint: "Das Einlesen endet beim ersten Syntaxfehler. Nach seiner Behebung werden weitere Probleme angezeigt.",
      location: fn(line, column) {
        "Zeile " <> int.to_string(line) <> ", Spalte " <> int.to_string(column)
      },
      schema_problem: schema_problem,
      too_complex: "das Dokument ist zu tief verschachtelt",
      too_large: fn(max_nodes) {
        "das Dokument hat mehr als " <> int.to_string(max_nodes) <> " Knoten"
      },
      preview_unavailable: "Vorschau nicht verfügbar",
      download_failed: "Download fehlgeschlagen",
      busy: "Der Server ist gerade ausgelastet. Bitte gleich noch einmal versuchen.",
      timed_out: "Das Setzen hat zu lange gedauert.",
      renderer_unavailable: "Der Renderer ist derzeit nicht verfügbar.",
      render_failed: "Der Lebenslauf konnte nicht gesetzt werden.",
      cannot_create_pdf: "PDF kann nicht erstellt werden",
      back_to_editor: "Zurück zum Editor",
    ),
    visual: VisualTexts(
      rewrite_title: "Bearbeiten hier schreibt das YAML neu",
      rewrite_body: "Die erste Änderung über die Blöcke schreibt das YAML in einheitlicher Form neu; Kommentare und eigene Formatierung gehen verloren.",
      style: "Stil",
      theme: "Design",
      colour: "Farbe",
      paper: "Papier",
      default_option: fn(name) { "Standard (" <> name <> ")" },
      person: "Person",
      name: "Name",
      title: "Titel",
      address: "Adresse",
      contact: "Kontakt",
      email: "E-Mail",
      phone: "Telefon",
      website: "Website",
      links: "Links",
      link: "Link",
      add_link: "Link hinzufügen",
      label: "Beschriftung",
      url: "URL",
      sections: "Abschnitte",
      section: "Abschnitt",
      kind: fn(kind) {
        case kind {
          "skills" -> "Fähigkeiten"
          "text" -> "Text"
          _ -> "Einträge"
        }
      },
      section_title: fn(kind) { "Abschnitt „" <> kind <> "“" },
      add_section: fn(kind) { "Abschnitt „" <> kind <> "“ hinzufügen" },
      heading: "Überschrift",
      text: "Text",
      entries: "Einträge",
      entry: "Eintrag",
      add_entry: "Eintrag hinzufügen",
      timespan: "Zeitraum",
      organisation: "Organisation",
      location: "Ort",
      bullets: "Aufzählungspunkte",
      bullet: "Punkt",
      add_bullet: "Punkt hinzufügen",
      skills: "Fähigkeiten",
      skill: "Fähigkeit",
      add_skill: "Fähigkeit hinzufügen",
      level: "Niveau",
      remove: "Entfernen",
      move_up: fn(item) { item <> " nach oben verschieben" },
      move_down: fn(item) { item <> " nach unten verschieben" },
      remove_item: fn(item) { item <> " entfernen" },
    ),
    schema: SchemaTexts(
      title: "Lebenslauf-Schema",
      intro: "Ein Lebenslauf ist ein YAML-Dokument. Nicht aufgeführte Schlüssel sind Fehler. Textwerte dürfen Zeichenketten oder Zahlen sein und nicht leer. Probleme erscheinen beim Tippen unter dem Editor.",
      key_header: "Schlüssel",
      requirement_header: "Pflicht",
      description_header: "Beschreibung",
      required: "Pflicht",
      optional: "optional",
      if_kind: fn(kind) { "wenn kind " <> kind <> " ist" },
      one_of: "Einer von:",
      default: "Standard:",
      document_title: "Dokument",
      document_intro: "Die oberste Ebene des Dokuments.",
      schema_version: "Schemaversion. Muss `1` sein.",
      style_key: "Gestaltung; siehe `style`.",
      person_key: "Um wen es geht; siehe `person`.",
      contact_key: "Kontaktdaten; siehe `contact`.",
      sections_key: "Die Abschnitte in ihrer Reihenfolge; siehe `sections[]`. Darf leer sein: `[]`.",
      style_intro: "Wie der Lebenslauf aussieht. Jeder Schlüssel hat einen Standardwert.",
      theme: "Layout und Typografie.",
      color: "Akzentfarbe.",
      paper: "Papierformat.",
      person_intro: "Steht oben im Lebenslauf.",
      person_name: "Vollständiger Name, als Überschrift gezeigt.",
      person_title: "Berufsbezeichnung oder Untertitel unter dem Namen.",
      person_address: "Postanschrift.",
      contact_intro: "Erreichbarkeit. Jeder Schlüssel ist optional.",
      email: "E-Mail-Adresse.",
      phone: "Telefonnummer.",
      website: "Adresse der Website.",
      links: "Weitere Links; siehe `contact.links[]`.",
      link_intro: "Jeder Eintrag der Linkliste.",
      link_label: "Angezeigter Text, zum Beispiel `GitHub`.",
      link_url: "Adresse, auf die der Link zeigt.",
      section_intro: "Jeder Abschnitt hat einen Namen und eine Art; die Art bestimmt, welcher Schlüssel den Inhalt enthält.",
      section_name: "Überschrift des Abschnitts.",
      section_kind: "Was der Abschnitt enthält.",
      section_entries: "Liste datierter Einträge; siehe `sections[].entries[]`.",
      section_items: "Liste von Fähigkeiten oder Sprachen; siehe `sections[].items[]`.",
      section_text: "Ein Absatz freier Text.",
      entry_intro: "Ein datierter Eintrag wie eine Stelle oder ein Abschluss.",
      timespan: "Zeitraum als Text, zum Beispiel `2019 – 2023` oder `seit 2020`.",
      entry_title: "Rolle, Abschluss oder Ähnliches.",
      organization: "Arbeitgeber, Schule oder Ähnliches.",
      location: "Stadt oder Ort.",
      bullets: "Liste von Textzeilen, als Aufzählungspunkte gezeigt.",
      skill_intro: "Eine Fähigkeit oder Sprache.",
      skill_name: "Name der Fähigkeit oder Sprache.",
      skill_level: "Niveau als Text, zum Beispiel `fließend`.",
    ),
  )
}

fn schema_problem(problem: decode.SchemaProblem) -> String {
  case problem {
    ExpectedMapping -> "muss eine Zuordnung (Mapping) sein"
    ExpectedOneDocument -> "muss genau ein YAML-Dokument sein"
    UnsupportedVersion(found:, supported:) ->
      "Version "
      <> int.to_string(found)
      <> " wird nicht unterstützt, erwartet "
      <> int.to_string(supported)
    ExpectedInteger -> "muss eine ganze Zahl sein"
    Required -> "fehlt (Pflichtfeld)"
    UnknownKey -> "unbekannter Schlüssel"
    MustNotBeEmpty -> "darf nicht leer sein"
    ExpectedText -> "muss Text sein"
    ExpectedList -> "muss eine Liste sein"
    ExpectedOneOf(names:) ->
      "muss einer dieser Werte sein: " <> string.join(names, ", ")
  }
}

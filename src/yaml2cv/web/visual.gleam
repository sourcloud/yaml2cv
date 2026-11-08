//// The visual editor: drafts as building blocks (ADR 0024).
////
//// The blocks form posts every edit to `/editor/visual/update`. Typing
//// leaves the blocks in place (`hx-swap="none"`); structural buttons (add,
//// remove, move) replace the form with the re-rendered blocks. Either way
//// the response carries the regenerated YAML out of band in `sync_id`,
//// which `editor.js` copies into the YAML source field.

import gleam/int
import gleam/list
import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html
import yaml2cv/cv
import yaml2cv/cv/decode
import yaml2cv/cv/draft.{
  type Draft, type Entry, type Link, type Section, type Skill, Entries, Skills,
  Text,
}
import yaml2cv/web/i18n/texts.{type Texts, type VisualTexts}
import yaml2cv/web/ui/alert
import yaml2cv/web/ui/block
import yaml2cv/web/ui/button
import yaml2cv/web/ui/field.{Optional}
import yaml2cv/web/visual_form.{
  type ListRef, type Op, Add, AddSection, Bullets, EntriesOf, Links, MoveDown,
  MoveUp, Remove, Sections, SkillsOf,
}

/// The id of the blocks form.
pub const form_id = "visual-form"

/// The id of the element that carries regenerated YAML to `editor.js`.
pub const sync_id = "yaml-sync"

const update_path = "/editor/visual/update"

/// The blocks form for `draft`, labelled in the language of `texts`.
pub fn view(draft: Draft, texts: Texts) -> Element(message) {
  let t = Labels(texts.visual, field.Required(texts.ui.required_marker))
  html.form(
    [
      attribute.id(form_id),
      attribute.class("visual-editor"),
      attribute.attribute("hx-post", update_path),
      // `flush` sends pending edits at once, before leaving visual mode.
      attribute.attribute("hx-trigger", "input delay:300ms, flush"),
      attribute.attribute("hx-swap", "none"),
      attribute.attribute("hx-sync", "this:queue all"),
    ],
    [
      alert.view(alert.Info, t.v.rewrite_title, [html.text(t.v.rewrite_body)]),
      style_block(t, draft.style),
      person_block(t, draft.person),
      contact_block(t, draft.contact),
      list_of(
        t.v.sections,
        list.index_map(draft.sections, fn(section, index) {
          section_block(t, section, index, list.length(draft.sections))
        }),
        list.map(decode.section_kinds, fn(kind) {
          op_button(AddSection(kind.0), t.v.add_section(t.v.kind(kind.0)), "")
        }),
      ),
    ],
  )
}

/// An empty placeholder for `sync`, rendered once in the page.
pub fn sync_placeholder() -> Element(message) {
  html.div([attribute.id(sync_id), attribute.attribute("hidden", "")], [])
}

/// The regenerated YAML, swapped out of band into `sync_placeholder`.
pub fn sync(yaml: String) -> Element(message) {
  html.textarea(
    [
      attribute.id(sync_id),
      attribute.attribute("hidden", ""),
      attribute.attribute("hx-swap-oob", "true"),
      attribute.data("yaml-sync", ""),
      attribute.aria_hidden(True),
    ],
    yaml,
  )
}

// --- Blocks ------------------------------------------------------------------

/// The texts the blocks use, with the marker for required fields.
type Labels {
  Labels(v: VisualTexts, required: field.Requirement)
}

fn style_block(t: Labels, style: draft.Style) -> Element(message) {
  let default = cv.default_style
  block.view(title: t.v.style, actions: [], body: [
    choice(t, "style.theme", t.v.theme, cv.themes, default.theme, style.theme),
    choice(t, "style.color", t.v.colour, cv.colors, default.color, style.color),
    choice(t, "style.paper", t.v.paper, cv.papers, default.paper, style.paper),
  ])
}

/// A select of the YAML names in `options`; `""` stands for the default.
fn choice(
  t: Labels,
  name: String,
  label: String,
  options: List(#(String, a)),
  default: a,
  value: String,
) -> Element(message) {
  let default_name = case
    list.find(options, fn(option) { option.1 == default })
  {
    Ok(option) -> option.0
    Error(Nil) -> ""
  }
  field.select(
    name:,
    label:,
    options: [
      #("", t.v.default_option(default_name)),
      ..list.map(options, fn(option) { #(option.0, option.0) })
    ],
    value:,
  )
}

fn person_block(t: Labels, person: draft.Person) -> Element(message) {
  block.view(title: t.v.person, actions: [], body: [
    text("person.name", t.v.name, person.name, t.required),
    text("person.title", t.v.title, person.title, Optional),
    text("person.address", t.v.address, person.address, Optional),
  ])
}

fn contact_block(t: Labels, contact: draft.Contact) -> Element(message) {
  let count = list.length(contact.links)
  block.view(title: t.v.contact, actions: [], body: [
    text("contact.email", t.v.email, contact.email, Optional),
    text("contact.phone", t.v.phone, contact.phone, Optional),
    text("contact.website", t.v.website, contact.website, Optional),
    list_of(
      t.v.links,
      list.index_map(contact.links, fn(link, index) {
        link_block(t, link, index, count)
      }),
      [op_button(Add(Links), t.v.add_link, "")],
    ),
  ])
}

fn link_block(
  t: Labels,
  link: Link,
  index: Int,
  count: Int,
) -> Element(message) {
  let prefix = visual_form.item_name(Links, index)
  block.view(
    title: numbered(t.v.link, index),
    actions: item_actions(t, Links, index, count, t.v.link),
    body: [
      text(prefix <> ".label", t.v.label, link.label, t.required),
      text(prefix <> ".url", t.v.url, link.url, t.required),
    ],
  )
}

fn section_block(
  t: Labels,
  section: Section,
  index: Int,
  count: Int,
) -> Element(message) {
  let prefix = visual_form.item_name(Sections, index)
  let kind = draft.kind_name(section.content)
  let content = case section.content {
    Entries(entries) -> {
      let count = list.length(entries)
      list_of(
        t.v.entries,
        list.index_map(entries, fn(entry, item) {
          entry_block(t, entry, index, item, count)
        }),
        [op_button(Add(EntriesOf(index)), t.v.add_entry, "")],
      )
    }
    Skills(skills) -> {
      let count = list.length(skills)
      list_of(
        t.v.skills,
        list.index_map(skills, fn(skill, item) {
          skill_block(t, skill, index, item, count)
        }),
        [op_button(Add(SkillsOf(index)), t.v.add_skill, "")],
      )
    }
    Text(value) ->
      field.textarea(
        name: prefix <> ".text",
        label: t.v.text,
        value:,
        requirement: t.required,
      )
  }
  block.view(
    title: t.v.section_title(t.v.kind(kind)),
    actions: item_actions(t, Sections, index, count, t.v.section),
    body: [
      html.input([
        attribute.type_("hidden"),
        attribute.name(prefix <> ".kind"),
        attribute.value(kind),
      ]),
      text(prefix <> ".name", t.v.heading, section.name, t.required),
      content,
    ],
  )
}

fn entry_block(
  t: Labels,
  entry: Entry,
  section: Int,
  index: Int,
  count: Int,
) -> Element(message) {
  let ref = EntriesOf(section)
  let prefix = visual_form.item_name(ref, index)
  let bullets = Bullets(section, index)
  let bullet_count = list.length(entry.bullets)
  block.view(
    title: numbered(t.v.entry, index),
    actions: item_actions(t, ref, index, count, t.v.entry),
    body: [
      text(prefix <> ".timespan", t.v.timespan, entry.timespan, t.required),
      text(prefix <> ".title", t.v.title, entry.title, t.required),
      text(
        prefix <> ".organization",
        t.v.organisation,
        entry.organization,
        Optional,
      ),
      text(prefix <> ".location", t.v.location, entry.location, Optional),
      list_of(
        t.v.bullets,
        list.index_map(entry.bullets, fn(bullet, item) {
          html.div([attribute.class("visual-editor__row")], [
            text(
              visual_form.item_name(bullets, item),
              numbered(t.v.bullet, item),
              bullet,
              t.required,
            ),
            html.div(
              [attribute.class("visual-editor__row-actions")],
              item_actions(t, bullets, item, bullet_count, t.v.bullet),
            ),
          ])
        }),
        [op_button(Add(bullets), t.v.add_bullet, "")],
      ),
    ],
  )
}

fn skill_block(
  t: Labels,
  skill: Skill,
  section: Int,
  index: Int,
  count: Int,
) -> Element(message) {
  let ref = SkillsOf(section)
  let prefix = visual_form.item_name(ref, index)
  block.view(
    title: numbered(t.v.skill, index),
    actions: item_actions(t, ref, index, count, t.v.skill),
    body: [
      text(prefix <> ".name", t.v.name, skill.name, t.required),
      text(prefix <> ".level", t.v.level, skill.level, Optional),
    ],
  )
}

// --- Parts -------------------------------------------------------------------

fn text(
  name: String,
  label: String,
  value: String,
  requirement: field.Requirement,
) -> Element(message) {
  field.text(name:, label:, value:, requirement:)
}

/// "Entry 2" for the item at index 1.
fn numbered(noun: String, index: Int) -> String {
  noun <> " " <> int.to_string(index + 1)
}

/// A labelled list of blocks followed by its add buttons.
fn list_of(
  label: String,
  items: List(Element(message)),
  add: List(Element(message)),
) -> Element(message) {
  html.div(
    [
      attribute.class("ui-block-list"),
      attribute.role("group"),
      attribute.aria("label", label),
    ],
    list.append(items, [
      html.div([attribute.class("visual-editor__add")], add),
    ]),
  )
}

/// Move up, move down and remove buttons for item `index` of `count`.
fn item_actions(
  t: Labels,
  ref: ListRef,
  index: Int,
  count: Int,
  noun: String,
) -> List(Element(message)) {
  let which = numbered(noun, index)
  let moves =
    list.flatten([
      case index > 0 {
        True -> [op_button(MoveUp(ref, index), "↑", t.v.move_up(which))]
        False -> []
      },
      case index + 1 < count {
        True -> [op_button(MoveDown(ref, index), "↓", t.v.move_down(which))]
        False -> []
      },
    ])
  let remove = op_button(Remove(ref, index), t.v.remove, t.v.remove_item(which))
  case moves {
    [] -> [remove]
    _ -> [html.div([attribute.class("visual-editor__move")], moves), remove]
  }
}

/// A button that posts the form with `op` and replaces it with the result.
/// `description` labels it for assistive technology when `label` is terse.
fn op_button(op: Op, label: String, description: String) -> Element(message) {
  let variant = case op {
    AddSection(..) | Add(..) -> button.Secondary
    _ -> button.Quiet
  }
  let class = case op {
    Remove(..) -> [attribute.class("visual-editor__remove")]
    _ -> []
  }
  button.view(
    variant,
    [
      attribute.type_("button"),
      attribute.name("op"),
      attribute.value(visual_form.op_value(op)),
      attribute.attribute("hx-post", update_path),
      attribute.attribute("hx-target", "#" <> form_id),
      attribute.attribute("hx-swap", "outerHTML"),
      attribute.attribute("hx-sync", "closest form:queue all"),
      ..list.append(class, described(description))
    ],
    label,
  )
}

fn described(description: String) -> List(Attribute(message)) {
  case description {
    "" -> []
    _ -> [attribute.aria_label(description), attribute.title(description)]
  }
}

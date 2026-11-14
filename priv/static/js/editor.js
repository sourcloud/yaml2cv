// Editor enhancements.
//
// - Textareas marked with `data-tab-indent`: Tab inserts spaces instead of
//   moving focus. Press Escape first to let the next Tab leave the field, so
//   keyboard users are never trapped. Enter keeps the line's indentation,
//   one level more after `key:` (ADR 0045).
// - Line-number gutters (`data-gutter-for`, ADR 0021) follow the line count
//   and scroll position of their textarea.
// - Buttons with `data-jump-field`, `data-jump-line` and `data-jump-column`
//   move the cursor to that 1-based position in the field.
// - Menu buttons (`[data-menu]`, ADR 0029) open their list on click or the
//   arrow keys, upwards when there is no room below; the arrow keys, Home and End move between the items, Escape
//   and a click elsewhere close it.
// - Buttons with `data-copy-from` copy that field's text to the clipboard
//   and briefly show `data-copied-label` (on the menu button when inside a
//   menu). `data-download-from` saves the field's text as a file named
//   `data-download-name`. `data-import-choose` opens the file input with
//   that id, whose `data-import-into` field gets the picked file's text,
//   undoably; in visual mode the blocks are then asked for again.
// - Buttons and links with `data-dialog-open` open the modal `<dialog>` with
//   that id; a click on its backdrop closes it (ADR 0022). The footer's
//   licenses link also fetches its content into the dialog with htmx, which
//   keeps the link from navigating (ADR 0032).
// - Edit modes (ADR 0024): `[data-mode]` holds `yaml` or `visual`. The
//   Visual switch asks the server for blocks via htmx and switches on its
//   `visual-ready` event. Regenerated YAML arrives in `#yaml-sync` and is
//   copied into the source field, firing `yaml-synced` so the status,
//   preview and gutter follow at once (ADR 0042). Switching back, or switching the language, flushes
//   pending block edits first. The editor form's `mode` field follows the
//   mode, so the language switch comes back in it.
// - Block buttons (`name="op"`) re-render all blocks. Afterwards the page
//   scrolls so the affected block stays where it was on screen, focus moves
//   to it, and it is briefly highlighted.
// - Photos (ADR 0028): `[data-photo-choose]` opens the file input
//   `[data-photo-input]` next to it. The picked JPEG or PNG is cropped to
//   3.5 : 4.5, scaled to at most 900 × 1157 pixels (ADR 0030) and
//   re-encoded as JPEG, which drops EXIF data such as the GPS location. The
//   result goes into the hidden input of its `[data-photo-field]`. The file
//   is not uploaded.
//   The choose button reads "change" and the remove button shows once
//   there is a photo.
// - Lean requests (ADR 0039, 0041, 0042): editor requests carry a
//   single-coloured PNG of the same pixel size instead of the photo, when
//   the photo is one the server would accept. Before a response is
//   swapped in, the placeholder in it is replaced by the real photo again.
(() => {
  "use strict";

  let escaped = false;

  document.addEventListener("keydown", (event) => {
    const field = event.target;
    if (!(field instanceof HTMLTextAreaElement) || !field.dataset.tabIndent) {
      return;
    }
    if (event.key === "Escape") {
      escaped = true;
      return;
    }
    if (event.key !== "Tab" || event.shiftKey || escaped) {
      escaped = false;
      return;
    }
    event.preventDefault();
    const indent = " ".repeat(Number(field.dataset.tabIndent) || 2);
    // execCommand keeps the browser's undo history intact.
    if (!document.execCommand("insertText", false, indent)) {
      field.setRangeText(indent, field.selectionStart, field.selectionEnd, "end");
      field.dispatchEvent(new Event("input", { bubbles: true }));
    }
  });

  // The indentation for a new line after `before`, the text left of the
  // cursor on its line (ADR 0045): the line's own, with list dashes as
  // spaces so the next key lines up with the item's first key, and one
  // level more after a line opening a block (`key:`, `key: |`, `key: >-`).
  const newlineIndent = (before, unit) => {
    const content = before.replace(/ +#.*$/, "").trimEnd();
    const lead = /^( *(?:- +)*)/.exec(before)[1].length;
    const opens = /(^|[^:]):$/.test(content) || /: *[|>][-+0-9]*$/.test(content);
    return " ".repeat(lead + (opens ? unit : 0));
  };

  document.addEventListener("keydown", (event) => {
    const field = event.target;
    if (!(field instanceof HTMLTextAreaElement) || !field.dataset.tabIndent) return;
    if (event.key !== "Enter" || event.shiftKey || event.altKey || event.ctrlKey || event.metaKey) {
      return;
    }
    if (event.isComposing) return;
    const start = field.selectionStart;
    const before = field.value.slice(field.value.lastIndexOf("\n", start - 1) + 1, start);
    const text = "\n" + newlineIndent(before, Number(field.dataset.tabIndent) || 2);
    event.preventDefault();
    // execCommand keeps the browser's undo history intact.
    if (!document.execCommand("insertText", false, text)) {
      field.setRangeText(text, field.selectionStart, field.selectionEnd, "end");
      field.dispatchEvent(new Event("input", { bubbles: true }));
    }
  });

  const gutterOf = (field) =>
    field instanceof HTMLTextAreaElement && field.id
      ? document.querySelector(`[data-gutter-for="${CSS.escape(field.id)}"]`)
      : null;

  const renumber = (field, gutter) => {
    const count = field.value.split("\n").length;
    if (Number(gutter.dataset.lines) !== count) {
      gutter.dataset.lines = String(count);
      gutter.textContent = Array.from({ length: count }, (_, i) => i + 1).join("\n");
      gutter.parentElement.style.setProperty(
        "--gutter-digits",
        String(Math.max(3, String(count).length)),
      );
    }
    gutter.scrollTop = field.scrollTop;
  };

  const sync = (event) => {
    const gutter = gutterOf(event.target);
    if (gutter) renumber(event.target, gutter);
  };

  document.addEventListener("input", sync);
  document.addEventListener("yaml-synced", sync);
  // Scroll events do not bubble; listen in the capture phase instead.
  document.addEventListener("scroll", sync, true);

  for (const gutter of document.querySelectorAll("[data-gutter-for]")) {
    const field = document.getElementById(gutter.dataset.gutterFor);
    if (field instanceof HTMLTextAreaElement) renumber(field, gutter);
  }

  document.addEventListener("click", (event) => {
    const button = event.target.closest?.("[data-jump-field]");
    if (!button) return;
    const field = document.getElementById(button.dataset.jumpField);
    if (!(field instanceof HTMLTextAreaElement)) return;
    const lines = field.value.split("\n");
    const line = Math.min(Math.max(Number(button.dataset.jumpLine) || 1, 1), lines.length);
    const column = Math.max(Number(button.dataset.jumpColumn) || 1, 1);
    let offset = 0;
    for (let i = 0; i < line - 1; i++) offset += lines[i].length + 1;
    offset += Math.min(column - 1, lines[line - 1].length);
    field.focus();
    field.setSelectionRange(offset, offset);
    // Show the line about a third down the field rather than at its edge.
    const lineHeight = parseFloat(getComputedStyle(field).lineHeight) || 20;
    field.scrollTop = Math.max(0, (line - 1) * lineHeight - field.clientHeight / 3);
    const gutter = gutterOf(field);
    if (gutter) gutter.scrollTop = field.scrollTop;
  });

  // --- Schema completion (ADR 0045) ---------------------------------------

  // The list dashes and the key of a block-style YAML line, with their
  // columns: "  - name: x" -> dash at 2, key `name` at 4 with value "x".
  // Blank and comment lines have none.
  const lineNodes = (line) => {
    const match = /^( *)((?:- +)*)(.*)$/.exec(line);
    if (!match || /^\s*(#.*)?$/.test(match[3]) && !match[2]) return [];
    const nodes = [];
    let col = match[1].length;
    for (const dash of match[2].match(/- +/g) || []) {
      nodes.push({ col, dash: true });
      col += dash.length;
    }
    const key = /^([A-Za-z_]\w*):(?: +(.*))?$/.exec(match[3]);
    if (key) nodes.push({ col, key: key[1], value: (key[2] || "").replace(/ #.*$/, "").trim() });
    return nodes;
  };

  // The path of the mapping that holds a key at column `col`, as written in
  // the completion data ("sections[].entries[]", "" for the root), or null
  // when the cursor is not inside a block mapping. `own` are the nodes left
  // of the cursor on its line; `above` the lines above it.
  const mappingPath = (above, own, col) => {
    const path = [];
    let afterDash = false;
    const visit = (node) => {
      if (node.dash) {
        if (node.col >= col) return true;
        path.unshift("[]");
        afterDash = true;
      } else {
        // A list may sit at the same column as the key it belongs to.
        if (node.col > col || (node.col === col && !afterDash)) return true;
        // Only a key without a value on its line holds nested content.
        if (node.value) return false;
        path.unshift(node.key);
        afterDash = false;
      }
      col = node.col;
      return true;
    };
    for (const node of [...own].reverse()) if (!visit(node)) return null;
    for (let i = above.length - 1; i >= 0 && (col > 0 || afterDash); i--) {
      for (const node of lineNodes(above[i]).reverse()) if (!visit(node)) return null;
    }
    return path.join(".").replaceAll(".[]", "[]");
  };

  // Keys already used in the mapping whose keys start at column `col`.
  const usedKeys = (above, below, own, col) => {
    const used = new Set();
    // A dash on the cursor's line starts a new item: nothing above is in it.
    if (!own.some((node) => node.dash)) {
      for (let i = above.length - 1; i >= 0; i--) {
        const nodes = lineNodes(above[i]);
        if (!nodes.length || nodes[0].col > col) continue;
        const key = nodes.find((node) => node.key && node.col === col);
        if (key) used.add(key.key);
        if (nodes[0].col < col) break;
      }
    }
    for (const line of below) {
      const nodes = lineNodes(line);
      if (!nodes.length || nodes[0].col > col) continue;
      if (nodes[0].col < col) break;
      if (nodes[0].key) used.add(nodes[0].key);
    }
    return used;
  };

  // What could be completed at `offset` in `text`: a key of the mapping at
  // `path`, or a value of its `key`, replacing `prefix` before the cursor.
  const completionContext = (text, offset) => {
    const lineStart = text.lastIndexOf("\n", offset - 1) + 1;
    const newline = text.indexOf("\n", offset);
    const lineEnd = newline < 0 ? text.length : newline;
    const before = text.slice(lineStart, offset);
    if (text.slice(offset, lineEnd).trim()) return null;
    const above = text.slice(0, lineStart).split("\n").slice(0, -1);
    const below = newline < 0 ? [] : text.slice(newline + 1).split("\n");
    const line = above.length;
    const value = /^( *(?:- +)*)([A-Za-z_]\w*): +([\w-]*)$/.exec(before);
    if (value) {
      const own = lineNodes(value[1]);
      const path = mappingPath(above, own, value[1].length);
      return path === null ? null : { kind: "value", path, key: value[2], prefix: value[3], line, col: before.length - value[3].length };
    }
    const key = /^( *(?:- +)*)([A-Za-z_]\w*)?$/.exec(before);
    if (!key) return null;
    const own = lineNodes(key[1]);
    const col = key[1].length;
    const path = mappingPath(above, own, col);
    if (path === null) return null;
    return { kind: "key", path, prefix: key[2] || "", used: usedKeys(above, below, own, col), line, col };
  };

  // The options for a context: [{ label, insert, note, detail }].
  const completionOptions = (data, context) => {
    const fields = data.mappings[context.path] || [];
    if (context.kind === "key") {
      return fields
        .filter((field) => field.key.startsWith(context.prefix) && !context.used.has(field.key))
        .map((field) => ({
          label: field.key,
          insert: field.nested ? `${field.key}:` : `${field.key}: `,
          note: field.requirement,
          detail: field.description,
        }));
    }
    const field = fields.find((candidate) => candidate.key === context.key);
    if (!field) return [];
    const options = field.values.filter((value) => value.startsWith(context.prefix));
    if (options.length === 1 && options[0] === context.prefix) return [];
    const detail = field.default
      ? `${field.description} ${data.labels.default} \`${field.default}\`.`
      : field.description;
    return options.map((value) => ({ label: value, insert: value, note: "", detail }));
  };

  // Text with the parts between backticks as <code>, built without markup.
  const richText = (element, text) => {
    element.replaceChildren(
      ...text.split("`").map((part, i) => {
        if (i % 2 === 0) return document.createTextNode(part);
        const code = document.createElement("code");
        code.textContent = part;
        return code;
      }),
    );
  };

  const completion = {
    field: null,
    box: null,
    list: null,
    detail: null,
    context: null,
    options: [],
    active: 0,
  };

  const completionData = (field) => {
    if (!field.dataset.completions) return null;
    if (!completionData.cache.has(field)) {
      let data = null;
      try {
        data = JSON.parse(field.dataset.completions);
      } catch {
        // Without data, the field simply offers no completions.
      }
      completionData.cache.set(field, data);
    }
    return completionData.cache.get(field);
  };
  completionData.cache = new WeakMap();

  const completionBox = (field) => {
    if (completion.field === field && completion.box?.isConnected) return completion.box;
    completion.box?.remove();
    const box = document.createElement("div");
    box.className = "ui-code-area__completion";
    box.hidden = true;
    const list = document.createElement("ul");
    list.className = "ui-code-area__options";
    list.id = `${field.id}-completions`;
    list.setAttribute("role", "listbox");
    list.setAttribute("aria-label", field.labels?.[0]?.textContent || "");
    const detail = document.createElement("p");
    detail.className = "ui-code-area__detail";
    box.append(list, detail);
    // Keep the focus in the field when an option is clicked.
    box.addEventListener("mousedown", (event) => event.preventDefault());
    box.addEventListener("click", (event) => {
      const option = event.target.closest("[role=option]");
      if (option) acceptCompletion(Number(option.dataset.index));
    });
    field.parentElement.append(box);
    field.setAttribute("aria-controls", list.id);
    Object.assign(completion, { field, box, list, detail });
    return box;
  };

  const closeCompletion = () => {
    if (!completion.box || completion.box.hidden) return;
    completion.box.hidden = true;
    completion.field?.removeAttribute("aria-activedescendant");
  };

  const highlight = (index) => {
    const { list, detail, options, field } = completion;
    completion.active = index;
    for (const option of list.children) {
      option.setAttribute("aria-selected", String(Number(option.dataset.index) === index));
    }
    const option = list.children[index];
    option.scrollIntoView({ block: "nearest" });
    field.setAttribute("aria-activedescendant", option.id);
    richText(detail, options[index].detail);
  };

  // Places the box below the cursor. Lines do not wrap and the font is
  // monospaced, so the position follows from the line and column.
  const placeCompletion = (field, box, context) => {
    const style = getComputedStyle(field);
    const canvas = placeCompletion.canvas || (placeCompletion.canvas = document.createElement("canvas"));
    const measure = canvas.getContext("2d");
    measure.font = `${style.fontStyle} ${style.fontWeight} ${style.fontSize} ${style.fontFamily}`;
    const charWidth = measure.measureText("m").width;
    const lineHeight = parseFloat(style.lineHeight) || 20;
    const left =
      field.offsetLeft + parseFloat(style.paddingLeft) + context.col * charWidth - field.scrollLeft;
    const top =
      field.offsetTop + parseFloat(style.paddingTop) + (context.line + 1) * lineHeight - field.scrollTop;
    const container = field.parentElement;
    box.style.left = `${Math.max(0, Math.min(left, container.clientWidth - box.offsetWidth))}px`;
    box.style.top = `${top}px`;
  };

  // Shows the options at the cursor; `force` also opens on an empty key.
  const updateCompletion = (field, force) => {
    const data = completionData(field);
    if (!data || field.selectionStart !== field.selectionEnd) return closeCompletion();
    const context = completionContext(field.value, field.selectionStart);
    if (!context || (!force && context.kind === "key" && !context.prefix)) return closeCompletion();
    const options = completionOptions(data, context);
    if (!options.length) return closeCompletion();
    const box = completionBox(field);
    const previous = completion.options[completion.active]?.label;
    completion.context = context;
    completion.options = options;
    completion.list.replaceChildren(
      ...options.map((option, index) => {
        const item = document.createElement("li");
        item.className = "ui-code-area__option";
        item.id = `${completion.list.id}-${index}`;
        item.dataset.index = String(index);
        item.setAttribute("role", "option");
        const label = document.createElement("span");
        label.textContent = option.label;
        item.append(label);
        if (option.note) {
          const note = document.createElement("span");
          note.className = "ui-code-area__option-note";
          note.textContent = option.note;
          item.append(note);
        }
        return item;
      }),
    );
    box.hidden = false;
    placeCompletion(field, box, context);
    highlight(Math.max(0, options.findIndex((option) => option.label === previous)));
  };

  const acceptCompletion = (index) => {
    const { field, context, options } = completion;
    const option = options[index];
    if (!field || !option) return;
    closeCompletion();
    field.focus();
    field.setSelectionRange(field.selectionStart - context.prefix.length, field.selectionStart);
    // execCommand keeps the browser's undo history intact.
    if (!document.execCommand("insertText", false, option.insert)) {
      field.setRangeText(option.insert, field.selectionStart, field.selectionEnd, "end");
      field.dispatchEvent(new Event("input", { bubbles: true }));
    }
    // A value follows a completed key: offer it right away.
    if (option.insert.endsWith(" ")) updateCompletion(field, false);
  };

  document.addEventListener("input", (event) => {
    const field = event.target;
    if (!(field instanceof HTMLTextAreaElement) || !field.dataset.completions) return;
    const open = completion.field === field && completion.box && !completion.box.hidden;
    if (event.inputType === "insertText" || open) updateCompletion(field, false);
    else closeCompletion();
  });

  // In the capture phase, so Tab and Escape are handled here before the
  // Tab indentation above sees them.
  document.addEventListener(
    "keydown",
    (event) => {
      const field = event.target;
      if (!(field instanceof HTMLTextAreaElement) || !field.dataset.completions) return;
      if (event.key === " " && event.ctrlKey && !event.altKey && !event.metaKey) {
        event.preventDefault();
        updateCompletion(field, true);
        return;
      }
      const open = completion.field === field && completion.box && !completion.box.hidden;
      if (!open) return;
      const count = completion.options.length;
      const move = {
        ArrowDown: (completion.active + 1) % count,
        ArrowUp: (completion.active - 1 + count) % count,
        PageDown: Math.min(completion.active + 5, count - 1),
        PageUp: Math.max(completion.active - 5, 0),
      }[event.key];
      if (move !== undefined && !event.altKey && !event.ctrlKey && !event.metaKey) {
        event.preventDefault();
        highlight(move);
      } else if ((event.key === "Enter" || event.key === "Tab") && !event.shiftKey) {
        event.preventDefault();
        event.stopImmediatePropagation();
        acceptCompletion(completion.active);
      } else if (event.key === "Escape") {
        event.preventDefault();
        event.stopImmediatePropagation();
        closeCompletion();
      } else if (["ArrowLeft", "ArrowRight", "Home", "End"].includes(event.key)) {
        closeCompletion();
      }
    },
    true,
  );

  document.addEventListener("focusout", (event) => {
    if (event.target === completion.field) closeCompletion();
  });
  document.addEventListener("mousedown", (event) => {
    if (event.target === completion.field) closeCompletion();
  });
  // Typing near the field's edge scrolls it; the list follows the cursor.
  document.addEventListener(
    "scroll",
    (event) => {
      const { field, box, context } = completion;
      if (event.target === field && box && !box.hidden) placeCompletion(field, box, context);
    },
    true,
  );

  // The Clipboard API needs a secure context (HTTPS or localhost); fall back
  // to selecting the text and the legacy copy command elsewhere.
  const copy = async (field) => {
    try {
      await navigator.clipboard.writeText(field.value);
      return true;
    } catch {
      field.focus();
      field.select();
      return document.execCommand("copy");
    }
  };

  const labels = new WeakMap();

  const flash = (button, text) => {
    if (!labels.has(button)) labels.set(button, { text: button.textContent });
    const state = labels.get(button);
    button.textContent = text;
    clearTimeout(state.timer);
    state.timer = setTimeout(() => {
      button.textContent = state.text;
    }, 2000);
  };

  // In visual mode, block edits wait for a debounce before they reach the
  // YAML. Actions that read the YAML run once those edits are in it.
  let afterFlush = null;

  const needsFlush = () => {
    const root = document.querySelector("[data-mode]");
    const form = document.getElementById("visual-form");
    return root?.dataset.mode === "visual" && Boolean(form?.dataset.dirty) && Boolean(window.htmx);
  };

  const whenFlushed = (action) => {
    if (!needsFlush()) return action();
    afterFlush = action;
    window.htmx.trigger(document.getElementById("visual-form"), "flush");
  };

  document.addEventListener("click", (event) => {
    const button = event.target.closest?.("[data-copy-from]");
    if (!button) return;
    const field = document.getElementById(button.dataset.copyFrom);
    if (!(field instanceof HTMLTextAreaElement)) return;
    const feedback = button.closest("[data-menu]")?.querySelector("[data-menu-trigger]") || button;
    whenFlushed(async () => {
      const copied = await copy(field);
      flash(
        feedback,
        copied
          ? button.dataset.copiedLabel || "Copied"
          : button.dataset.copyFailedLabel || "Copy failed",
      );
    });
  });

  document.addEventListener("click", (event) => {
    const button = event.target.closest?.("[data-download-from]");
    if (!button) return;
    const field = document.getElementById(button.dataset.downloadFrom);
    if (!(field instanceof HTMLTextAreaElement)) return;
    whenFlushed(() => {
      const url = URL.createObjectURL(new Blob([field.value], { type: "application/yaml" }));
      const link = document.createElement("a");
      link.href = url;
      link.download = button.dataset.downloadName || "cv.yaml";
      document.body.append(link);
      link.click();
      link.remove();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
    });
  });

  document.addEventListener("click", (event) => {
    const button = event.target.closest?.("[data-import-choose]");
    if (button) document.getElementById(button.dataset.importChoose)?.click();
  });

  // Replaces the field's text; execCommand keeps the browser's undo history.
  const replaceText = (field, text) => {
    field.focus();
    field.select();
    if (!document.execCommand("insertText", false, text)) {
      field.value = text;
      field.dispatchEvent(new Event("input", { bubbles: true }));
    }
  };

  document.addEventListener("change", async (event) => {
    const input = event.target;
    if (!(input instanceof HTMLInputElement) || !input.dataset.importInto) return;
    const file = input.files?.[0];
    input.value = "";
    if (!file) return;
    const failed = () => window.alert(input.dataset.importFailedLabel || "The file could not be imported.");
    const max = Number(input.dataset.importMaxBytes) || Infinity;
    if (file.size > max) return failed();
    let text;
    try {
      text = await file.text();
    } catch {
      return failed();
    }
    const field = document.getElementById(input.dataset.importInto);
    if (!(field instanceof HTMLTextAreaElement)) return;
    const root = field.closest("[data-mode]");
    const visual = root?.dataset.mode === "visual";
    // The field is hidden in visual mode, and focus and undo need it shown.
    if (visual) setMode(root, "yaml");
    replaceText(field, text);
    if (visual) root.querySelector('[data-mode-switch="visual"]')?.click();
  });

  // --- Menu buttons -----------------------------------------------------------

  const menuParts = (menu) => ({
    trigger: menu.querySelector("[data-menu-trigger]"),
    list: menu.querySelector('[role="menu"]'),
    items: [...menu.querySelectorAll('[role="menuitem"]')],
  });

  const openMenu = (menu, focus) => {
    const { trigger, list, items } = menuParts(menu);
    list.classList.remove("ui-menu__list--up");
    list.hidden = false;
    // Open upwards when the list would leave the viewport below and there is
    // more room above, as for a button at the bottom of the page.
    const below = window.innerHeight - trigger.getBoundingClientRect().bottom;
    const above = trigger.getBoundingClientRect().top;
    const height = list.getBoundingClientRect().height;
    if (height > below && above > below) list.classList.add("ui-menu__list--up");
    trigger.setAttribute("aria-expanded", "true");
    (focus === "last" ? items.at(-1) : items[0])?.focus();
  };

  const closeMenu = (menu, refocus) => {
    const { trigger, list } = menuParts(menu);
    if (list.hidden) return;
    list.hidden = true;
    trigger.setAttribute("aria-expanded", "false");
    if (refocus) trigger.focus();
  };

  document.addEventListener("click", (event) => {
    const menu = event.target.closest?.("[data-menu]");
    for (const open of document.querySelectorAll("[data-menu]")) {
      if (open !== menu) closeMenu(open, false);
    }
    if (!menu) return;
    if (event.target.closest("[data-menu-trigger]")) {
      if (menuParts(menu).list.hidden) openMenu(menu, "first");
      else closeMenu(menu, false);
    } else if (event.target.closest('[role="menuitem"]')) {
      closeMenu(menu, true);
    }
  });

  document.addEventListener("keydown", (event) => {
    const menu = event.target.closest?.("[data-menu]");
    if (!menu) return;
    const { items } = menuParts(menu);
    if (event.target.closest("[data-menu-trigger]")) {
      if (event.key === "ArrowDown" || event.key === "ArrowUp") {
        event.preventDefault();
        openMenu(menu, event.key === "ArrowUp" ? "last" : "first");
      }
      return;
    }
    const at = items.indexOf(event.target);
    if (at < 0) return;
    const go = {
      ArrowDown: (at + 1) % items.length,
      ArrowUp: (at - 1 + items.length) % items.length,
      Home: 0,
      End: items.length - 1,
    }[event.key];
    if (go !== undefined) {
      event.preventDefault();
      items[go].focus();
    } else if (event.key === "Escape") {
      event.preventDefault();
      closeMenu(menu, true);
    } else if (event.key === "Tab") {
      closeMenu(menu, false);
    }
  });

  document.addEventListener("click", (event) => {
    const opener = event.target.closest?.("[data-dialog-open]");
    if (opener) {
      const dialog = document.getElementById(opener.dataset.dialogOpen);
      if (dialog instanceof HTMLDialogElement && !dialog.open) dialog.showModal();
      return;
    }
    // A click on the backdrop targets the dialog element itself, outside its
    // content box. Browsers supporting `closedby="any"` handle this natively.
    const dialog = event.target;
    if (dialog instanceof HTMLDialogElement && dialog.open) {
      const box = dialog.getBoundingClientRect();
      const inside =
        event.clientX >= box.left && event.clientX <= box.right &&
        event.clientY >= box.top && event.clientY <= box.bottom;
      if (!inside) dialog.close();
    }
  });

  const setMode = (root, mode) => {
    root.dataset.mode = mode;
    delete root.dataset.pendingMode;
    const field = root.querySelector("[data-mode-field]");
    if (field) field.value = mode;
    for (const button of root.querySelectorAll("[data-mode-switch]")) {
      button.setAttribute("aria-pressed", String(button.dataset.modeSwitch === mode));
    }
  };

  document.addEventListener("visual-ready", (event) => {
    const root = event.target.closest?.("[data-mode]");
    if (root) setMode(root, "visual");
  });

  document.addEventListener("input", (event) => {
    const form = event.target.closest?.("#visual-form");
    if (form) form.dataset.dirty = "true";
  });

  document.addEventListener("click", (event) => {
    const button = event.target.closest?.('[data-mode-switch="yaml"]');
    const root = button?.closest("[data-mode]");
    if (!root || root.dataset.mode !== "visual") return;
    const form = document.getElementById("visual-form");
    if (form?.dataset.dirty && window.htmx) {
      // Switch once the pending edits are in the YAML.
      root.dataset.pendingMode = "yaml";
      window.htmx.trigger(form, "flush");
    } else {
      setMode(root, "yaml");
    }
  });

  // The language switch posts the YAML; edits still waiting in the blocks
  // go into it first, then the switch is submitted again.
  document.addEventListener("click", (event) => {
    const choice = event.target.closest?.("[data-language-choice]");
    if (!choice || !needsFlush()) return;
    event.preventDefault();
    whenFlushed(() => choice.form?.requestSubmit(choice));
  });

  const applySync = () => {
    const sync = document.getElementById("yaml-sync");
    if (!(sync instanceof HTMLTextAreaElement) || sync.dataset.applied) return;
    sync.dataset.applied = "true";
    const root = document.querySelector("[data-mode]");
    // Late answers must not overwrite YAML typed after leaving visual mode.
    if (!root || root.dataset.mode !== "visual") return;
    const field = document.getElementById("cv");
    if (field instanceof HTMLTextAreaElement && field.value !== sync.value) {
      field.value = sync.value;
      // Not `input`: the edit was debounced already, so the preview is
      // asked for at once (ADR 0042).
      field.dispatchEvent(new Event("yaml-synced", { bubbles: true }));
    }
    if (root.dataset.pendingMode) setMode(root, root.dataset.pendingMode);
    const action = afterFlush;
    afterFlush = null;
    action?.();
  };

  document.addEventListener("htmx:oobAfterSwap", applySync);
  document.addEventListener("htmx:afterSettle", applySync);

  let anchor = null;

  // A menu item is hidden once its menu closes; its menu button stands in.
  const shown = (button) =>
    button.closest("[data-menu]")?.querySelector("[data-menu-trigger]") || button;

  document.addEventListener("htmx:beforeRequest", (event) => {
    const button = event.detail.elt;
    if (button instanceof HTMLButtonElement && button.name === "op") {
      anchor = { op: button.value, top: shown(button).getBoundingClientRect().top };
    }
  });

  // Button values to look for after the swap, best first: the moved item's
  // buttons at its new index, the item that took a removed one's place, or
  // the add button that was clicked.
  const anchorCandidates = (op) => {
    const [action, path] = op.split(":");
    const parts = path.split(".");
    const index = Number(parts.pop());
    const list = parts.join(".");
    const item = (i) => `${list}.${i}`;
    const addList = list === "sections" ? "add-section:entries" : `add:${list}`;
    switch (action) {
      case "up":
      case "down": {
        const moved = item(action === "up" ? index - 1 : index + 1);
        return [`${action}:${moved}`, `up:${moved}`, `down:${moved}`, `remove:${moved}`];
      }
      case "remove":
        return [`remove:${item(index)}`, `remove:${item(index - 1)}`, addList];
      default:
        return [op];
    }
  };

  const restoreAnchor = () => {
    const form = document.getElementById("visual-form");
    if (!anchor || !form) return;
    const { op, top } = anchor;
    anchor = null;
    const button = anchorCandidates(op)
      .map((value) => form.querySelector(`button[name="op"][value="${CSS.escape(value)}"]`))
      .find(Boolean);
    if (!button) return;
    window.scrollBy(0, shown(button).getBoundingClientRect().top - top);
    // A new item sits right before its add button; start typing there.
    const added = op.startsWith("add")
      ? button.closest(".visual-editor__add")?.previousElementSibling
      : null;
    const field = added?.querySelector("input:not([type=hidden]), textarea");
    (field || shown(button)).focus({ preventScroll: true });
    const block = (added || button).closest(".visual-editor__row, .ui-block");
    if (block && !op.startsWith("remove")) {
      block.classList.add("ui-block--moved");
      block.addEventListener("animationend", () => block.classList.remove("ui-block--moved"), { once: true });
    }
  };

  document.addEventListener("htmx:afterSettle", restoreAnchor);
  const photoWidth = 900;
  const photoHeight = 1157;

  // Decodes, crops to cover the photo box and re-encodes as JPEG.
  const preparePhoto = async (file) => {
    if (!["image/jpeg", "image/png"].includes(file.type)) throw new Error("type");
    const bitmap = await createImageBitmap(file, { imageOrientation: "from-image" });
    const ratio = photoWidth / photoHeight;
    let sw = bitmap.width;
    let sh = bitmap.height;
    if (sw / sh > ratio) sw = sh * ratio;
    else sh = sw / ratio;
    const sx = (bitmap.width - sw) / 2;
    const sy = (bitmap.height - sh) / 2;
    const width = Math.round(Math.min(photoWidth, sw));
    const height = Math.round(width / ratio);
    const canvas = document.createElement("canvas");
    canvas.width = width;
    canvas.height = height;
    const context = canvas.getContext("2d");
    // A transparent PNG gets a white background instead of black.
    context.fillStyle = "#fff";
    context.fillRect(0, 0, width, height);
    context.drawImage(bitmap, sx, sy, sw, sh, 0, 0, width, height);
    bitmap.close();
    return canvas.toDataURL("image/jpeg", 0.85);
  };

  const showPhoto = (container, uri) => {
    const value = container.querySelector("[data-photo-value]");
    const thumbnail = container.querySelector("[data-photo-thumbnail]");
    const choose = container.querySelector("[data-photo-choose]");
    const remove = container.querySelector("[data-photo-remove]");
    value.value = uri;
    if (uri) thumbnail.src = uri;
    else thumbnail.removeAttribute("src");
    thumbnail.hidden = !uri;
    choose.textContent = uri ? choose.dataset.changeLabel : choose.dataset.chooseLabel;
    remove.hidden = !uri;
    // The removed button had focus; keep it in the field.
    if (!uri) choose.focus();
    value.dispatchEvent(new Event("input", { bubbles: true }));
  };

  document.addEventListener("click", (event) => {
    const choose = event.target.closest?.("[data-photo-choose]");
    if (choose) {
      choose.parentElement.querySelector("[data-photo-input]")?.click();
      return;
    }
    const remove = event.target.closest?.("[data-photo-remove]");
    const container = remove?.closest("[data-photo-field]");
    if (!container) return;
    // A removed photo is not kept in memory for later responses (ADR 0043).
    placeholders.clear();
    realPhotos.clear();
    showPhoto(container, "");
  });

  document.addEventListener("change", async (event) => {
    const input = event.target;
    if (!(input instanceof HTMLInputElement) || !("photoInput" in input.dataset)) return;
    const file = input.files?.[0];
    input.value = "";
    if (!file) return;
    const container = input.closest("[data-photo-field]");
    if (!container) return;
    let uri;
    try {
      uri = await preparePhoto(file);
    } catch {
      window.alert(container.dataset.photoFailedLabel || "The photo could not be read.");
      return;
    }
    showPhoto(container, uri);
  });
  const photoPattern = /data:image\/(jpeg|png);base64,[A-Za-z0-9+/]+={0,2}/g;
  const maxPhotoBytes = 524288;
  const maxPhotoSide = 4000;
  // Real photo URI -> placeholder URI (null when it has to be sent), and back.
  const placeholders = new Map();
  const realPhotos = new Map();

  const decodeBase64 = (text) => {
    if (text.length % 4 !== 0 || (text.length / 4) * 3 > maxPhotoBytes + 2) return null;
    let binary;
    try {
      binary = atob(text);
    } catch {
      return null;
    }
    if (binary.length > maxPhotoBytes) return null;
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
    return bytes;
  };

  const ascii = (bytes, start, length) =>
    String.fromCharCode(...bytes.subarray(start, start + length));

  // Size of a complete PNG without EXIF data, else null.
  const pngSize = (bytes, view) => {
    if (bytes.length < 33 || ascii(bytes, 0, 8) !== "\x89PNG\r\n\x1a\n") return null;
    if (ascii(bytes, 12, 4) !== "IHDR") return null;
    const size = { width: view.getUint32(16), height: view.getUint32(20) };
    for (let at = 8; at + 12 <= bytes.length; ) {
      const type = ascii(bytes, at + 4, 4);
      if (type === "eXIf") return null;
      if (type === "IEND") return size;
      at += 12 + view.getUint32(at);
    }
    return null;
  };

  // Size of a complete JPEG without EXIF data, else null. Walks the
  // segments up to the first frame header like the server does.
  const jpegSize = (bytes, view) => {
    const end = bytes.length;
    if (end < 4 || bytes[0] !== 0xff || bytes[1] !== 0xd8) return null;
    if (bytes[end - 2] !== 0xff || bytes[end - 1] !== 0xd9) return null;
    let at = 2;
    while (at + 4 <= end) {
      if (bytes[at] !== 0xff) return null;
      const marker = bytes[at + 1];
      if (marker === 0xff) {
        at += 1;
      } else if (marker === 0x01 || (marker >= 0xd0 && marker <= 0xd7)) {
        at += 2;
      } else {
        const length = view.getUint16(at + 2);
        if (length < 2) return null;
        if (marker === 0xe1 && ascii(bytes, at + 4, 6) === "Exif\0\0") return null;
        const frame =
          marker >= 0xc0 && marker <= 0xcf && ![0xc4, 0xc8, 0xcc].includes(marker);
        if (frame) {
          if (at + 9 > end) return null;
          return { height: view.getUint16(at + 5), width: view.getUint16(at + 7) };
        }
        if (marker === 0xda || marker === 0xd9) return null;
        at += 2 + length;
      }
    }
    return null;
  };

  const makePlaceholder = (uri) => {
    const [prefix, encoded] = uri.split(",");
    const bytes = decodeBase64(encoded);
    if (!bytes) return null;
    const view = new DataView(bytes.buffer);
    const size = prefix.includes("png") ? pngSize(bytes, view) : jpegSize(bytes, view);
    if (!size) return null;
    const { width, height } = size;
    if (width < 1 || height < 1 || width > maxPhotoSide || height > maxPhotoSide) return null;
    const canvas = document.createElement("canvas");
    canvas.width = width;
    canvas.height = height;
    const context = canvas.getContext("2d");
    context.fillStyle = "#d4d4d4";
    context.fillRect(0, 0, width, height);
    const placeholder = canvas.toDataURL("image/png");
    return placeholder.startsWith("data:image/png;base64,") && placeholder.length < uri.length
      ? placeholder
      : null;
  };

  const placeholderFor = (uri) => {
    if (!placeholders.has(uri)) {
      // Keep the last few photos, enough for requests still in flight.
      if (placeholders.size >= 4) {
        const [oldest, placeholder] = placeholders.entries().next().value;
        placeholders.delete(oldest);
        realPhotos.delete(placeholder);
      }
      const placeholder = makePlaceholder(uri);
      placeholders.set(uri, placeholder);
      if (placeholder) realPhotos.set(placeholder, uri);
    }
    return placeholders.get(uri);
  };

  // Every htmx request of the editor: the YAML, and the photo field of the
  // visual blocks (ADR 0042). Downloads and the language switch are plain
  // form submits and keep the real photo.
  document.addEventListener("htmx:configRequest", (event) => {
    const data = event.detail.formData;
    if (!data) return;
    const entries = [...data.entries()];
    let changed = false;
    const lean = entries.map(([name, value]) => {
      if (typeof value !== "string" || !value.includes(";base64,")) return [name, value];
      const replaced = value.replace(photoPattern, (uri) => placeholderFor(uri) ?? uri);
      if (replaced !== value) changed = true;
      return [name, replaced];
    });
    if (!changed) return;
    for (const name of new Set(entries.map(([name]) => name))) data.delete(name);
    for (const [name, value] of lean) data.append(name, value);
  });

  document.addEventListener("htmx:beforeSwap", (event) => {
    let html = event.detail.serverResponse;
    if (typeof html !== "string" || !html.includes(";base64,")) return;
    for (const [placeholder, real] of realPhotos) {
      if (html.includes(placeholder)) html = html.split(placeholder).join(real);
    }
    event.detail.serverResponse = html;
  });
})();

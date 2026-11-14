// Editor enhancements.
//
// - Textareas marked with `data-tab-indent`: Tab inserts spaces instead of
//   moving focus. Press Escape first to let the next Tab leave the field, so
//   keyboard users are never trapped.
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
    if (container) showPhoto(container, "");
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

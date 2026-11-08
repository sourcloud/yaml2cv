// Editor enhancements.
//
// - Textareas marked with `data-tab-indent`: Tab inserts spaces instead of
//   moving focus. Press Escape first to let the next Tab leave the field, so
//   keyboard users are never trapped.
// - Line-number gutters (`data-gutter-for`, ADR 0021) follow the line count
//   and scroll position of their textarea.
// - Buttons with `data-jump-field`, `data-jump-line` and `data-jump-column`
//   move the cursor to that 1-based position in the field.
// - Buttons with `data-copy-from` copy that field's text to the clipboard
//   and briefly show `data-copied-label`.
// - Buttons with `data-dialog-open` open the modal `<dialog>` with that id;
//   a click on its backdrop closes it (ADR 0022).
// - Edit modes (ADR 0024): `[data-mode]` holds `yaml` or `visual`. The
//   Visual switch asks the server for blocks via htmx and switches on its
//   `visual-ready` event. Regenerated YAML arrives in `#yaml-sync` and is
//   copied into the source field, firing `input` so validation, preview
//   and the gutter follow. Switching back flushes pending block edits first.
// - Block buttons (`name="op"`) re-render all blocks. Afterwards the page
//   scrolls so the affected block stays where it was on screen, focus moves
//   to it, and it is briefly highlighted.
// - Photos (ADR 0028): `[data-photo-choose]` opens the file input
//   `[data-photo-input]` next to it. The picked JPEG or PNG is cropped to
//   3.5 : 4.5, scaled to at most 600 × 771 pixels and re-encoded as JPEG,
//   which drops EXIF data such as the GPS location. The result goes into the
//   hidden input of a `[data-photo-field]` or, for `data-photo-yaml`, into
//   the `person.photo` line of that YAML field. The file is not uploaded.
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

  document.addEventListener("click", async (event) => {
    const button = event.target.closest?.("[data-copy-from]");
    if (!button) return;
    const field = document.getElementById(button.dataset.copyFrom);
    if (!(field instanceof HTMLTextAreaElement)) return;
    if (!labels.has(button)) labels.set(button, { text: button.textContent });
    const state = labels.get(button);
    const copied = await copy(field);
    button.textContent = copied
      ? button.dataset.copiedLabel || "Copied"
      : button.dataset.copyFailedLabel || "Copy failed";
    clearTimeout(state.timer);
    state.timer = setTimeout(() => {
      button.textContent = state.text;
    }, 2000);
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
      field.dispatchEvent(new Event("input", { bubbles: true }));
    }
    if (root.dataset.pendingMode) setMode(root, root.dataset.pendingMode);
  };

  document.addEventListener("htmx:oobAfterSwap", applySync);
  document.addEventListener("htmx:afterSettle", applySync);

  let anchor = null;

  document.addEventListener("htmx:beforeRequest", (event) => {
    const button = event.detail.elt;
    if (button instanceof HTMLButtonElement && button.name === "op") {
      anchor = { op: button.value, top: button.getBoundingClientRect().top };
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
    window.scrollBy(0, button.getBoundingClientRect().top - top);
    // A new item sits right before its add button; start typing there.
    const added = op.startsWith("add")
      ? button.closest(".visual-editor__add")?.previousElementSibling
      : null;
    const field = added?.querySelector("input:not([type=hidden]), textarea");
    (field || button).focus({ preventScroll: true });
    const block = (added || button).closest(".visual-editor__row, .ui-block");
    if (block && !op.startsWith("remove")) {
      block.classList.add("ui-block--moved");
      block.addEventListener("animationend", () => block.classList.remove("ui-block--moved"), { once: true });
    }
  };

  document.addEventListener("htmx:afterSettle", restoreAnchor);
  const photoWidth = 600;
  const photoHeight = 771;

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

  // Sets `photo:` in the block-style `person:` mapping, replacing an existing
  // value (and its continuation lines). Returns null without such a block.
  const withYamlPhoto = (yaml, uri) => {
    const lines = yaml.split("\n");
    const start = lines.findIndex((line) => /^person:\s*(#.*)?$/.test(line));
    if (start < 0) return null;
    let end = start + 1;
    let indent = null;
    while (end < lines.length && (lines[end].trim() === "" || /^\s/.test(lines[end]))) {
      if (indent === null && lines[end].trim() !== "") indent = lines[end].match(/^\s+/)[0];
      end++;
    }
    indent ??= "  ";
    const line = `${indent}photo: ${uri}`;
    const at = lines.slice(start + 1, end).findIndex((l) => l.startsWith(`${indent}photo:`));
    if (at < 0) {
      // After the last key of the block, where the canonical layout has it.
      let last = end;
      while (last > start + 1 && lines[last - 1].trim() === "") last--;
      lines.splice(last, 0, line);
    } else {
      const first = start + 1 + at;
      let next = first + 1;
      while (next < end && lines[next].startsWith(`${indent} `)) next++;
      lines.splice(first, next - first, line);
    }
    return lines.join("\n");
  };

  const replaceText = (field, text) => {
    field.focus();
    field.select();
    // execCommand keeps the browser's undo history intact.
    if (!document.execCommand("insertText", false, text)) {
      field.value = text;
      field.dispatchEvent(new Event("input", { bubbles: true }));
    }
  };

  const showPhoto = (container, uri) => {
    const value = container.querySelector("[data-photo-value]");
    const thumbnail = container.querySelector("[data-photo-thumbnail]");
    const remove = container.querySelector("[data-photo-remove]");
    value.value = uri;
    if (uri) thumbnail.src = uri;
    else thumbnail.removeAttribute("src");
    thumbnail.hidden = !uri;
    if (remove) remove.disabled = !uri;
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
    const labelled = input.closest("[data-photo-field]") || input;
    let uri;
    try {
      uri = await preparePhoto(file);
    } catch {
      window.alert(labelled.dataset.photoFailedLabel || "The photo could not be read.");
      return;
    }
    const container = input.closest("[data-photo-field]");
    if (container) {
      showPhoto(container, uri);
      return;
    }
    const field = document.getElementById(input.dataset.photoYaml || "");
    if (!(field instanceof HTMLTextAreaElement)) return;
    const yaml = withYamlPhoto(field.value, uri);
    if (yaml === null) window.alert(input.dataset.photoNeedsPersonLabel || "");
    else replaceText(field, yaml);
  });
})();

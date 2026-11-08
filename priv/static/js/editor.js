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
    button.textContent = copied ? button.dataset.copiedLabel || "Copied" : "Copy failed";
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
})();

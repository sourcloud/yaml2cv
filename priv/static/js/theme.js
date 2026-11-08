// Colour theme switch (ADR 0012). Loaded synchronously in <head> so the
// stored theme is applied before the first paint.
(() => {
  "use strict";

  const key = "yaml2cv-theme";
  const root = document.documentElement;

  const stored = () => {
    try {
      const value = localStorage.getItem(key);
      return value === "light" || value === "dark" ? value : "system";
    } catch {
      return "system"; // storage blocked, e.g. by privacy settings
    }
  };

  const apply = (choice) => {
    if (choice === "system") {
      delete root.dataset.theme;
    } else {
      root.dataset.theme = choice;
    }
  };

  const store = (choice) => {
    try {
      if (choice === "system") {
        localStorage.removeItem(key);
      } else {
        localStorage.setItem(key, choice);
      }
    } catch {
      // Not persisted; the choice still applies to this page.
    }
  };

  apply(stored());

  document.addEventListener("DOMContentLoaded", () => {
    for (const control of document.querySelectorAll(".ui-theme-switch")) {
      const options = control.querySelectorAll("[data-theme-choice]");
      const mark = (choice) => {
        for (const option of options) {
          const active = option.dataset.themeChoice === choice;
          option.setAttribute("aria-pressed", String(active));
        }
      };
      for (const option of options) {
        option.addEventListener("click", () => {
          const choice = option.dataset.themeChoice;
          apply(choice);
          store(choice);
          mark(choice);
        });
      }
      mark(stored());
      control.hidden = false;
    }
  });
})();

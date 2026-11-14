// Records the README demo (ADR 0044): drives the editor of a running
// yaml2cv instance through its main interactions and saves a video.
//
//   node record.mjs [base-url] [out-dir]
//
// The video is converted to docs/demo.gif by `just demo-gif`.

import { chromium } from "playwright";
import { mkdir, readdir, rename, rm } from "node:fs/promises";
import { join } from "node:path";

const baseUrl = process.argv[2] ?? "http://localhost:8000";
const outDir = process.argv[3] ?? "build/demo";
const size = { width: 1280, height: 720 };

// A visible pointer: headless recordings do not show the mouse.
const pointerScript = () => {
  addEventListener("DOMContentLoaded", () => {
    const dot = document.createElement("div");
    Object.assign(dot.style, {
      position: "fixed",
      left: "0",
      top: "0",
      width: "18px",
      height: "18px",
      margin: "-9px 0 0 -9px",
      borderRadius: "50%",
      background: "rgba(220, 38, 38, 0.55)",
      border: "2px solid rgba(255, 255, 255, 0.9)",
      boxShadow: "0 0 0 1px rgba(0, 0, 0, 0.25)",
      pointerEvents: "none",
      zIndex: "2147483647",
      transition: "transform 120ms",
      transform: "translate(-100px, -100px)",
    });
    document.body.append(dot);
    let x = -100;
    let y = -100;
    const place = (scale) =>
      (dot.style.transform = `translate(${x}px, ${y}px) scale(${scale})`);
    addEventListener("mousemove", (event) => {
      x = event.clientX;
      y = event.clientY;
      place(1);
    }, true);
    addEventListener("mousedown", () => place(0.7), true);
    addEventListener("mouseup", () => place(1), true);
  });
};

const pause = (page, ms) => page.waitForTimeout(ms);

// Moves the pointer to the centre of an element in visible steps.
async function pointAt(page, locator) {
  const box = await locator.boundingBox();
  await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2, {
    steps: 20,
  });
  await pause(page, 250);
}

async function click(page, locator) {
  await pointAt(page, locator);
  await locator.click();
}

// Waits until the preview request triggered by the last edit has finished.
async function settle(page) {
  await page.waitForLoadState("networkidle");
  await pause(page, 400);
}

// Selects `text` inside the YAML textarea, as a double-click would.
async function selectInYaml(page, text) {
  const yaml = page.locator("#cv");
  await pointAt(page, yaml);
  await yaml.evaluate((area, needle) => {
    const start = area.value.indexOf(needle);
    area.focus();
    area.setSelectionRange(start, start + needle.length);
  }, text);
  await pause(page, 500);
}

async function typeSlowly(page, text) {
  await page.keyboard.type(text, { delay: 90 });
}

async function main() {
  await rm(outDir, { recursive: true, force: true });
  await mkdir(outDir, { recursive: true });

  const browser = await chromium.launch();
  const context = await browser.newContext({
    viewport: size,
    locale: "en-GB",
    colorScheme: "light",
    acceptDownloads: true,
    recordVideo: { dir: outDir, size },
  });
  await context.addInitScript(pointerScript);
  const page = await context.newPage();

  await page.goto(baseUrl);
  await settle(page);
  await page.mouse.move(640, 400);
  await pause(page, 1500);

  // 1. Edit the YAML: the preview follows.
  await selectInYaml(page, "My personal CV");
  await typeSlowly(page, "Software Engineer");
  await settle(page);
  await pause(page, 1200);

  // 2. A mistake is reported while typing, then fixed.
  await selectInYaml(page, "blue");
  await typeSlowly(page, "teal");
  await settle(page);
  await pointAt(page, page.locator("#validation"));
  await pause(page, 2200);
  await selectInYaml(page, "teal");
  await typeSlowly(page, "green");
  await settle(page);
  await pause(page, 1500);

  // 3. Visual mode: the same CV as blocks.
  await click(page, page.locator('[data-mode-switch="visual"]'));
  await settle(page);
  await pause(page, 1200);
  const theme = page.locator('select[name="style.theme"]');
  await click(page, theme);
  await theme.selectOption("studio");
  await settle(page);
  await pause(page, 1800);
  const color = page.locator('select[name="style.color"]');
  await click(page, color);
  await color.selectOption("burgundy");
  await settle(page);
  await pause(page, 1800);

  // 4. Download the PDF.
  const download = page.waitForEvent("download");
  await click(page, page.getByRole("button", { name: "Download PDF" }));
  await download;
  await pause(page, 1500);

  await context.close();
  await browser.close();

  const [video] = (await readdir(outDir)).filter((f) => f.endsWith(".webm"));
  await rename(join(outDir, video), join(outDir, "demo.webm"));
  console.log(join(outDir, "demo.webm"));
}

await main();

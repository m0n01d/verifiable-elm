// Copyright 2026 Anthropic PBC
// SPDX-License-Identifier: Apache-2.0
//
// Capture the repo's documentation screenshots of the /verify routes.
// Run `npm run screenshot` — it builds, serves, captures, and cleans up.
// Saves PNGs under docs/screenshots/.
import { chromium } from "@playwright/test";
import { spawn } from "node:child_process";

const BASE = "http://localhost:5199";
const shots = [
  // The matrix list: every unit × fixture × verdict.
  { url: `${BASE}/verify`, out: "docs/screenshots/dashboard.png", wait: "table" },
  // A passing unit page: the live todo list on the left, its verification
  // report on the right.
  {
    url: `${BASE}/verify/TodoApp/three-mixed?chrome=0`,
    out: "docs/screenshots/unit-pass.png",
    wait: "[data-verify-unit]",
  },
  // The designed-to-fail probe: the report on the right shows the FAIL.
  {
    url: `${BASE}/verify/TodoStats/inconsistent-counts?chrome=0`,
    out: "docs/screenshots/unit-fail.png",
    wait: "[data-verify-unit]",
  },
];

// Serve the already-built app as an SPA, exactly like `npm run dev`.
const server = spawn("npx", ["serve", "-s", ".", "-l", "5199"], { stdio: "ignore" });

async function waitForServer(timeoutMs = 30000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    try {
      const r = await fetch(BASE);
      if (r.ok) return;
    } catch {
      // not up yet
    }
    await new Promise((res) => setTimeout(res, 200));
  }
  throw new Error(`server never came up at ${BASE}`);
}

try {
  await waitForServer();
  const browser = await chromium.launch();
  for (const { url, out, wait } of shots) {
    const page = await browser.newPage({ viewport: { width: 1100, height: 720 } });
    await page.goto(url, { waitUntil: "networkidle" });
    await page.waitForSelector(wait); // let Elm paint its first frame
    await page.screenshot({ path: out, fullPage: true });
    console.log(`wrote ${out}`);
    await page.close();
  }
  await browser.close();
} finally {
  server.kill();
}

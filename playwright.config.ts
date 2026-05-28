// Copyright 2026 Anthropic PBC
// SPDX-License-Identifier: Apache-2.0
import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./playwright",
  fullyParallel: true,
  reporter: [["list"]],
  use: {
    baseURL: "http://localhost:5199",
  },
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }],
  // Build the app and serve it as an SPA (so /verify/:unit/:fixture deep links
  // resolve to index.html and Elm routes client-side).
  webServer: {
    command: "npm run build && npx serve -s . -l 5199",
    url: "http://localhost:5199",
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
});

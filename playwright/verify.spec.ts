// Copyright 2026 Anthropic PBC
// SPDX-License-Identifier: Apache-2.0
//
// The real-DOM half of verification (README ideas #1, #3, #5). elm-test proves
// the pure model logic; this proves the *shipped artifact* behaves — by driving
// the live browser exactly as an AI agent would.

import { test, expect, Page } from "@playwright/test";

// ---------------------------------------------------------------------------
// Helpers that talk to the agent handle and the data-verify-* DOM contract.
// ---------------------------------------------------------------------------

type RunResult = {
  unit: string;
  fixture: string;
  probe: boolean;
  verdict: "PASS" | "FAIL" | "BLOCKED" | "SKIP";
  reason: string;
  surface: Record<string, string>;
};

async function callVerify(page: Page, method: "manifest" | "runAll" | "current") {
  return page.evaluate((m) => (window as any).__verify[m](), method);
}

// Assert a data-verify-* attribute on the live DOM — the machine-readable
// surface, not framework internals. Uses an auto-retrying assertion so we
// observe the value *after* Elm's next render frame, not before it.
async function expectAttr(page: Page, key: string, value: string) {
  await expect(page.locator(`[data-verify-${key}]`).first()).toHaveAttribute(
    `data-verify-${key}`,
    value,
  );
}

test.describe("window.__verify agent handle (idea #5)", () => {
  test("manifest lists every unit, fixture, and deep-link route", async ({ page }) => {
    await page.goto("/verify");
    const manifest = await callVerify(page, "manifest");

    const units = manifest.units.map((u: any) => u.name);
    expect(units).toContain("TodoApp");
    expect(units).toContain("TodoStats");

    // Every unit advertises at least one probe and a real route.
    for (const u of manifest.units) {
      expect(u.fixtures.length).toBeGreaterThan(0);
      expect(u.fixtures.some((f: any) => f.probe)).toBe(true);
      for (const f of u.fixtures) {
        expect(f.route).toBe(`/verify/${u.name}/${f.name}`);
      }
    }
  });

  test("runAll matches the elm-test matrix: one designed FAIL, rest pass", async ({ page }) => {
    await page.goto("/verify");
    const results: RunResult[] = await callVerify(page, "runAll");

    const fails = results.filter((r) => r.verdict === "FAIL");
    expect(fails.map((r) => `${r.unit}/${r.fixture}`)).toEqual([
      "TodoStats/inconsistent-counts",
    ]);

    // The failure is observed-and-wrong, with a precise diagnosis.
    expect(fails[0].reason).toContain("invariants/counts-add-up");
  });

  test("current() reports just the mounted fixture", async ({ page }) => {
    await page.goto("/verify/TodoStats/inconsistent-counts?chrome=0");
    const results: RunResult[] = await callVerify(page, "current");
    expect(results).toHaveLength(1);
    expect(results[0].fixture).toBe("inconsistent-counts");
    expect(results[0].verdict).toBe("FAIL");
  });
});

test.describe("isolated unit routes + DOM contract (ideas #1, #3)", () => {
  test("three-mixed renders the promised surface on the live DOM", async ({ page }) => {
    await page.goto("/verify/TodoApp/three-mixed?chrome=0");
    await expectAttr(page, "unit", "TodoApp");
    await expectAttr(page, "total", "3");
    await expectAttr(page, "done", "1");
    await expectAttr(page, "active", "2");
  });

  test("filter-active narrows the visible count but not the total", async ({ page }) => {
    await page.goto("/verify/TodoApp/filter-active?chrome=0");
    await expectAttr(page, "total", "3");
    await expectAttr(page, "visible", "2");
    await expectAttr(page, "filter", "active");
  });
});

test.describe("behavioral probe at the real surface (idea #2 act())", () => {
  test("typing whitespace and submitting does NOT add a todo", async ({ page }) => {
    await page.goto("/verify/TodoApp/empty?chrome=0");
    await expectAttr(page, "total", "0");

    // Drive the actual form — real input handler, real submit.
    await page.getByLabel("New todo").fill("    ");
    await page.getByRole("button", { name: "Add" }).click();

    // The surface must not have moved.
    await expectAttr(page, "total", "0");

    // A real todo, by contrast, does move it.
    await page.getByLabel("New todo").fill("Real task");
    await page.getByRole("button", { name: "Add" }).click();
    await expectAttr(page, "total", "1");
  });
});

test.describe("the harness catches lies (designed-to-fail probe)", () => {
  test("inconsistent-counts surfaces a FAIL verdict in the live report", async ({ page }) => {
    await page.goto("/verify/TodoStats/inconsistent-counts");
    // The rendered surface itself is the lie: 2 + 2 advertised as total 3.
    await expectAttr(page, "total", "3");
    await expectAttr(page, "done", "2");
    await expectAttr(page, "active", "2");

    // And the report renders the FAIL for a human.
    await expect(page.locator(".verdict-FAIL").first()).toBeVisible();
  });
});

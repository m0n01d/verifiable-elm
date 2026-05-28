<!-- Copyright 2026 Anthropic PBC -->
<!-- SPDX-License-Identifier: Apache-2.0 -->

# Verification, explained — a walkthrough for new contributors

This is the onboarding companion to the [README](README.md). The README states
the *philosophy*; this doc explains how verification actually works in this
repo, in plain terms, and walks through the gotcha you're most likely to hit on
day one.

## The one big idea

> **Run the real app, then have something read what it actually shows on screen
> — and check that against the rules.**

Most projects verify code by *reading* it or running unit tests *offline*. This
project's philosophy is the opposite: don't trust the code, trust the **running
artifact**. An AI agent (or you) should be able to open the app, poke it, and
get a machine-readable yes/no answer to "is this behaving correctly?"

The README calls this *"runtime observation at the surface."*

## The vocabulary

| Term | Plain English |
|---|---|
| **Unit** | A piece of the app we verify (here: `TodoApp` and `TodoStats`). |
| **Surface** | The handful of facts a unit broadcasts about itself, e.g. `total=3, done=1, active=2`. Rendered into the HTML as `data-verify-*` attributes. |
| **Fixture** | A starting state to test from — a `Model` plus a list of actions (`Msg` steps) to apply. |
| **Invariant** | A rule that must always hold. A function `Model -> Maybe String`: `Nothing` = rule holds; `Just "reason"` = rule broke, here's why. |
| **Check** | One pass/fail result from running a verifier. |
| **Verdict** | The roll-up: `PASS`, `FAIL`, `BLOCKED`, or `SKIP`. |

One subtlety worth internalizing early: **`BLOCKED` ≠ `FAIL`**. `FAIL` means "I
looked and it's wrong." `BLOCKED` means "I couldn't even observe it." They're
kept distinct on purpose — see [`src/Verify/Core.elm`](src/Verify/Core.elm).

## How a single verification runs

Look at the `run` function in any spec, e.g.
[`src/Verify/Specs/TodoStats.elm`](src/Verify/Specs/TodoStats.elm). Every unit
follows this exact shape:

1. **Find the fixture** by name (a known starting state).
2. **Compute the surface** — the facts the unit declares about itself.
3. **Run the checks** — apply every invariant + the DOM-contract checks.
4. **Roll up into one verdict** via `verdictFromChecks`.

`verdictFromChecks` ([`src/Verify/Core.elm`](src/Verify/Core.elm)) is dead
simple: *any* failing check → `FAIL`; *zero* checks → `BLOCKED`; otherwise →
`PASS`.

Here's a real invariant — "the counts must add up":

```elm
\m ->
    if m.done + m.active == m.total then
        Nothing          -- rule holds, all good
    else
        Just "done (2) + active (2) /= total (3)"   -- broke, and here's exactly why
```

## The "aha" example: a test designed to FAIL

There's a fixture called **`inconsistent-counts`** in
[`src/Verify/Specs/TodoStats.elm`](src/Verify/Specs/TodoStats.elm) that
deliberately ships a broken model — `total=3` but `done(2) + active(2) = 4`:

```elm
{ name = "inconsistent-counts"
, probe = True
, model = { total = 3, done = 2, active = 2 }   -- 2 + 2 ≠ 3, on purpose
}
```

Why intentionally break it? Because a verification framework that only ever says
"PASS" is useless — you can't tell whether it's actually checking anything. This
fixture proves the framework **catches lies**. The matrix test even asserts this
is the *only* fixture allowed to fail. A `probe` is an adversarial test — every
unit is *required* to have at least one, so you can't ship a unit that only
replays the happy path.

## The two tiers — where it gets clever

Verification runs in **two places**, and they share the same logic:

```
┌─ PURE tier (npm test) ───────────┐   ┌─ DOM tier (npm run verify) ──────┐
│ elm-test                         │   │ Playwright (real Chromium)       │
│ a fixture is JUST a Model        │   │ navigates real routes            │
│ "act()" = List.foldl update      │   │ reads data-verify-* from real    │
│ runs invariants, no browser      │   │ DOM, types into the real form    │
└──────────────────────────────────┘   └──────────────────────────────────┘
            both call the SAME Runner.runAll
       → green in one predicts green in the other
```

- **Pure tier** is cheap and hermetic — no browser, just fold the fixture's
  steps through the real `update` function and check invariants.
- **DOM tier** confirms the *shipped* app actually renders that surface in a
  real browser and the buttons/inputs are wired up.

Because both tiers run the **same** `Runner.runAll`, you get fast feedback
locally and high-confidence feedback in CI without writing the checks twice.

## The four commands you'll use

```
npm run typecheck   # elm make — does it compile?
npm test            # PURE tier — 6 tests, no browser
npm run verify      # DOM tier — 7 tests, real Chromium via Playwright
npm run dev         # run the app + /verify dashboard at localhost:5199
```

## The agent handle: `window.__verify`

Since the whole point is "an AI can verify this," the app exposes a global in the
browser ([`index.html`](index.html) bridges to Elm ports):

```js
__verify.manifest()        // list every unit × fixture × verifier
await __verify.current()    // result for whatever's currently mounted
await __verify.runAll()     // run the whole matrix, get structured results
```

The `/verify` dashboard you see in the browser is just a pretty rendering of
*that same data*. **Agent and human see the same truth.**

## Try this on your first day

1. `npm run dev`, open <http://localhost:5199/verify>
2. In the browser console: `await window.__verify.runAll()` — watch everything
   pass except the one designed-to-fail probe.
3. Now **break something on purpose**: in [`src/Todos.elm`](src/Todos.elm), find
   `surface` and change the `total` value to something wrong (e.g.
   `1 + List.length model.todos`). Re-run. Watch the invariant fail with a
   *precise* diagnosis — in the dashboard, in `npm test`, AND in
   `npm run verify`. That "same failure, everywhere" is the entire payoff.

---

## Troubleshooting: "`npm run verify` passes but `npm test` fails!"

This is the #1 newcomer trap, and it does **not** mean the framework is
inconsistent. It almost always means the DOM tier tested a **stale build**.

### Why it happens

The DOM tier serves a *compiled* artifact (`elm.js`), not your `.elm` source:

| Tool | What it runs against |
|---|---|
| `npm test` (elm-test) | Compiles **fresh from source** every run → always sees your latest edit. |
| dashboard | Whatever `elm.js` the running server has. |
| `npm run verify` (Playwright) | Whatever server is on `:5199` — and it **reuses an already-running one**. |

The culprit is one line in [`playwright.config.ts`](playwright.config.ts):

```ts
reuseExistingServer: !process.env.CI,
```

If you have `npm run dev` running in another terminal, Playwright sees a server
already on `:5199` and **reuses it instead of rebuilding**. But `serve` does not
recompile when you edit a `.elm` file — so that server is frozen on the code as
it was when `npm run dev` last built it. Your edit never reached the browser
Playwright drove.

So: `npm test` fails (fresh compile, sees the bug), while `npm run verify`
passes (stale server, old code). That green is a **false pass**.

### How to confirm it's a stale build

```bash
# Is a dev server holding :5199?
lsof -nP -iTCP:5199 -sTCP:LISTEN

# Does what the server serves match what's on disk?
curl -s http://localhost:5199/elm.js > /tmp/served.js
diff -q /tmp/served.js elm.js     # "differ" → the served build is stale
```

### The fix

Kill the stale dev server (or just close that terminal) and re-run
`npm run verify` — with nothing on `:5199`, Playwright runs its own
`npm run build && serve` and tests *your* code. Or, while iterating, restart
`npm run dev` after each edit so it rebuilds.

### The lesson worth tattooing on day one

> Verification only means something if the thing you're driving was built from
> the code you changed.

When `verify` and `npm test` disagree, **suspect a stale build before you
suspect the framework.** With Elm + a static `serve`, editing `.elm` does
nothing until something re-runs `elm make`.

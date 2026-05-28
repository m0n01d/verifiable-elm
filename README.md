<!-- Copyright 2026 Anthropic PBC -->
<!-- SPDX-License-Identifier: Apache-2.0 -->

# Verifiable Elm

The phase-3 verification philosophy ported to Elm. Same one idea: **every piece
of the app should be trivially verifiable by an AI agent at runtime**, not just
by a human reading code or a test suite running offline.

> **Credit / origin.** This is an Elm port of the "Verifiable React" phase-3
> demo from Anthropic's *How We Claude Code* workshop:
> <https://github.com/anthropics/cwc-workshops/tree/main/how-we-claude-code/phase-3-verify>.
> All six ideas below are theirs; this repo just re-expresses them in Elm. Their
> original is Apache-2.0, and so is this.

Verification is *runtime observation at the surface* — run the thing, drive it,
read what it actually shows. Tests and typechecks are CI's job; a verifier's job
is to confirm the real artifact behaves.

> **New here?** [`VERIFICATION.md`](VERIFICATION.md) is a plain-language
> walkthrough of how verification works — the vocabulary, the two tiers, a
> hands-on "break it on purpose" exercise, and the stale-build gotcha that trips
> up most newcomers (`npm run verify` passing while `npm test` fails).

```
npm install
npm run verify:install   # one-time: download Chromium for Playwright

npm run dev          # app on http://localhost:5199
                     #   /verify          dashboard
                     #   /verify/:unit/:fixture   isolated unit (+ ?chrome=0)
npm test             # the CI matrix, pure (elm-test) — 6 tests
npm run verify       # the CI matrix, real DOM (Playwright) — 7 tests
npm run typecheck    # elm make, no output
```

## The two tiers of verification

This is the one structural difference from the React version, and it falls
straight out of Elm's purity. Verification splits cleanly in two:

| tier | runs in | verifies | how |
|---|---|---|---|
| **pure** | `elm-test` + `window.__verify` | model logic + the declared surface | folds fixture steps through the real `update`, runs invariants |
| **DOM** | Playwright | the *shipped artifact* | navigates real routes, reads `data-verify-*`, types into the real form |

The pure tier is cheap and hermetic — an Elm fixture is *just a `Model`*, and
`act()` is just `List.foldl update model steps`. The DOM tier confirms the live
browser actually renders that surface and the event wiring works. Both call the
**same** `Runner.runAll`, so green in one predicts green in the other.

## The six ideas (Elm flavor)

### 1. The DOM is the machine-readable surface

Every unit emits `data-verify-*` attributes from a single `Surface` value, so
the rendered markup and the verifiers read **one source of truth** —
[`src/Verify/Contract.elm`](src/Verify/Contract.elm):

```elm
section (verifyAttrs (Todos.surface model)) [ ... ]
-- <section data-verify-unit="TodoApp" data-verify-total="3"
--          data-verify-done="1" data-verify-active="2" data-verify-filter="all">
```

### 2. Verifiable units declare fixtures + invariants

Each unit registers fixtures and invariants in
[`src/Verify/Specs/`](src/Verify/Specs/):

- a **fixture** is a starting `Model` plus a list of `Msg` **steps** (Elm's pure
  `act()` — driven by `List.foldl update`)
- an **invariant** is `Model -> Surface -> Maybe String` (`Nothing` = holds)

The **Zod-schema verifier is gone** — the Elm compiler already proves props
match their type. That budget goes to behavioral probes instead. Fixtures
flagged `probe = True` are adversarial; every unit is required (by the matrix
test) to have at least one.

### 3. Isolated render targets: `/verify/:unit/:fixture`

[`src/Main.elm`](src/Main.elm) routes each unit × fixture to a deep-linkable page
that mounts *only that unit* in known state. `TodoApp` mounts **interactively**
(the real component, seeded from the fixture — Playwright drives it); `TodoStats`
mounts **statically**. Append `?chrome=0` for a clean screenshot.

### 4. Pluggable verifiers

Verifiers are independent of components. The pure ones live in the spec/contract
layer; the DOM ones live in Playwright:

| verifier | tier | checks |
|---|---|---|
| `invariants` | pure | the unit's declared predicates hold |
| `dom-contract` | pure + DOM | `data-verify-*` present and self-identifying |
| `a11y` | DOM | buttons named, inputs labeled (`getByLabel`/`getByRole`) |

Adding one is: add a check, register it. No component changes.

### 5. `window.__verify` — the agent handle

Elm has no globals, so [`index.html`](index.html) bridges to the runtime over two
ports (`verifyRequest` / `verifyResponse` in [`src/Main.elm`](src/Main.elm)):

```js
__verify.manifest()       // every unit × fixture × verifier
__verify.current()        // structured result for what's mounted
await __verify.runAll()   // run the full matrix, return results
```

The `/verify` dashboard is just a human rendering of the same data. Agent and
human see the same truth.

### 6. One verdict taxonomy, three consumers

`PASS | FAIL | BLOCKED | SKIP`, checks as `ok ✅ | fail ❌ | warn ⚠️ | probe 🔍`
([`src/Verify/Core.elm`](src/Verify/Core.elm)). The same `Runner.runAll` feeds the
dashboard, `window.__verify.runAll()`, and the `elm-test` matrix. `BLOCKED`
(couldn't observe) is deliberately distinct from `FAIL` (observed and wrong).

## File layout

```
src/
  Todos.elm                the actual app (emits data-verify-* via Contract)
  TodoStats.elm            a display-only unit (hosts the designed-to-fail probe)
  Verify/
    Core.elm               Verdict, Check, Unit (type-erased), verdictFromChecks
    Contract.elm           Surface + verifyAttrs + dom-contract checks
    Registry.elm           the one list every consumer iterates
    Runner.elm             mount → drive → verify → verdict
    Encode.elm             the JSON window.__verify returns
    Harness.elm            dashboard + report views
    Specs/
      TodoApp.elm          fixtures + invariants for the interactive feature
      TodoStats.elm        fixtures + invariants, incl. inconsistent-counts
  Main.elm                 application, routing, the window.__verify ports
tests/
  MatrixTest.elm           the CI path: assert every unit×fixture verdict
playwright/
  verify.spec.ts           the real-DOM path: manifest, runAll, behavioral probes
index.html                 mounts Elm + installs window.__verify
```

## Try it with an agent

1. `npm run dev`
2. Tell an agent: "Open `/verify`, run `window.__verify.manifest()`, pick a
   unit, navigate to its route, and confirm
   `(await window.__verify.current())[0].verdict === 'PASS'`."
3. Break something — e.g. change `( "total", ... )` in `Todos.surface` to a
   wrong value — and watch the `surface-matches-model` invariant fail with a
   precise diagnosis, in the dashboard AND `npm test` AND `npm run verify` AND
   at `window.__verify`.

## Things deliberately demonstrated

- **`TodoStats/inconsistent-counts`** is a probe **designed to fail** — its
  fixture model claims `total = 3` while `done + active = 4`, so
  `counts-add-up` fails. It proves the framework catches lies, not just confirms
  truths. The matrix test asserts this is the *only* failing fixture.
- **`TodoApp/whitespace-submit`** drives the real form with whitespace through
  `update` and asserts the count didn't change — a behavioral probe at the
  feature surface. Playwright re-runs the same scenario against the live DOM.
- Every unit is required (by `MatrixTest.elm`) to have at least one probe
  fixture — you can't ship a unit that only replays the happy path.

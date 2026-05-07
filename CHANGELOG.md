# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

<!-- changelog -->

## Unreleased

Developer workflow and HexDocs structure.

- Added a root `Makefile` for setup, demo, compile, test, e2e, benchmark, docs, and Hex package build workflows.
- Expanded ExDoc configuration with grouped guides, grouped API modules, logo/favicon assets, canonical HexDocs URL, benchmark docs, and install-skill references.
- Added a documentation maintenance guide and tightened development/benchmark docs around the new `make` entrypoints.
- Fixed the Vite SSR adapter moduledoc fence so `mix docs --warnings-as-errors` passes cleanly.

## v0.11.2

Todo benchmark flow comparison hardening.

- Versioned the `/todo` interaction flow definition so release-to-release duration and interaction-byte comparisons only run when the same workflow is being measured.
- Kept the new LiveView-native Todo proof strict through absolute budgets, browser e2e, native form/stream assertions, URL-state assertions, and benchmark proof rows.
- Documented the benchmark policy distinction between product-flow changes and apples-to-apples performance regressions.

## v0.11.1

LiveView-native capability mimicry in the Todo demo.

- Added a LiveView control plane to `/todo` with native `phx-change` validation, `phx-submit` creation, URL-driven `push_patch` filters, a `Phoenix.LiveView.JS` inspector toggle, and a server-rendered activity stream.
- Kept the React workspace and Vue rhythm panel synchronized from the same server-owned URL and task state, so island interactions visibly round-trip through LiveView rather than acting like isolated frontend widgets.
- Extended Todo e2e and benchmark schema `version: 9` assertions to prove the LiveView control plane, native form, native stream, stream updates, URL state, SSR islands, deferred island, and island event replies all work in one product flow.

## v0.11.0

Complex Todo demo app with product-workflow benchmarks.

- Added a full-screen `/todo` demo app that uses LiveView as the source of truth while composing React and Vue islands in one polished product surface.
- Exercised React SSR, Vue SSR, server-only islands, deferred server islands, `client={:load | :visible | :interaction}`, `prefetch={:load | :idle | :intent}`, event replies, LiveView event pushes, and page-scoped manifests in one workflow.
- Added React islands for the workspace, focus timer, command center, SSR digest, and deferred digest, plus a Vue rhythm panel with visible hydration and mode events.
- Added browser e2e coverage for the full Todo workflow, including task creation, event-reply planning, Vue mode switching, command-center interaction, focus timer hydration, server-only hook absence, and manifest assertions.
- Extended benchmark schema `version: 9` with `/todo` initial bytes, JavaScript bytes, hydrated island counts, deferred SSR bytes, event-reply interaction timing, budgets, Markdown proof output, and release-to-release comparison metrics.

## v0.10.0

Island-aware asset profiles and page profile benchmarks.

- Added `LiveIslands.asset_profile/2` and `LiveIslands.put_asset_profile/3` so routes can request `:server_only`, `:css_only`, `:zero_js`, `:islands`, `:liveview`, or explicit Vite assets through a stable API.
- Replaced the example app's handwritten CSS-only shell assign with `LiveIslands.put_asset_profile(:server_only)`.
- Added `/profile/react-only`, `/profile/vue-only`, and `/profile/mixed` example routes to prove page-scoped manifests stay specific to each route's islands.
- Added browser e2e coverage for the profile matrix and extended benchmark schema `version: 8` with profile page byte totals, JavaScript totals, hydration counts, budgets, and release-to-release comparison metrics.
- Documented the next stage: v0.11.0 will focus on a complex demo app that exercises the full React + Vue + SSR + deferred + lazy loading stack in one realistic product surface.

## v0.9.0

Route-level shell optimization for server-only pages.

- Added CSS-only root-layout asset support so a route can render server-only React/Vue SSR islands without loading the Phoenix app entry.
- Updated `LiveIslands.Reload.vite_assets` to skip Vite dev client and React refresh scripts automatically when no JavaScript assets are requested.
- Extended `/server-only` e2e coverage to prove there are no module scripts, no LiveSocket boot, no prefetch/deferred runtime, no script responses, and no forbidden framework chunks.
- Extended benchmark schema `version: 7` with shell evidence and zero-JS budgets that require `/server-only` JavaScript bytes and script responses to stay at zero.

## v0.8.0

Server-only zero-JS proofs.

- Added a production `/server-only` example route with React and Vue SSR islands rendered without LiveView hooks or client hydration.
- Added browser e2e coverage proving the server-only page renders both framework outputs, emits no hydration/prefetch island events, and does not load forbidden React/Vue client chunks.
- Kept the root `live_islands` JavaScript export framework-neutral so importing `getIslandHooks` does not fetch React/Vue hook adapters before a page needs them.
- Extended the benchmark result schema with a `serverOnly` page, zero-JS evidence, stability rows, budgets, and release-to-release comparison metrics.
- Documented the exact zero-JS boundary: server-only islands avoid React/Vue client work while the Phoenix root page may still load its normal app entry.

## v0.7.0

Intent-aware prefetch and modulepreload evidence.

- Added `prefetch={:intent}` for React and Vue islands, using visible soft intent plus high-priority pointer/focus/touch intent while respecting save-data and slow-network signals.
- Upgraded the prefetch queue with priority, reprioritization, modulepreload events, skip events, and richer `live-islands:prefetch:*` event metadata.
- Added optional `preloadUrls(name)` support to React and Vue island registries so apps can provide concrete modulepreload URLs from their Vite manifest.
- Added an intent prefetch probe to the example app and browser e2e coverage proving the component does not load before intent, then loads with modulepreload evidence after pointer intent.
- Extended the benchmark runner with an intent prefetch flow, modulepreload counts, new flow budgets, and release-to-release comparison metrics.

## v0.6.0

Deferred server islands and measurable prefetch behavior.

- Added signed deferred server islands for `<.react_server defer={true}>` and `<.vue_server defer={true}>`, including fallback slots, timeout attributes, cache-control metadata, and the `LiveIslands.Deferred` plug.
- Added a tiny deferred runtime that fetches final SSR HTML after the shell response and dispatches `live-islands:deferred:*` events for benchmarks and tests.
- Upgraded island prefetching into a smart observable queue with bounded concurrency, optional modulepreload URLs, and `live-islands:prefetch:*` runtime events.
- Extended the benchmark route and runner to verify deferred fallback HTML, no final HTML leak in the shell response, deferred fetch bytes, deferred load timing, and server-only hook absence.
- Added browser e2e coverage for deferred server islands and moved e2e execution into the main GitHub Tests workflow.
- Opted GitHub workflows into the Node 24 JavaScript action runtime ahead of the runner migration.

## v0.5.0

Runtime splitting and benchmark-driven regression policy.

- Split the root LiveIslands client entry so React and Vue hook adapters load lazily when their islands mount instead of being bundled into the initial application entry.
- Made island prefetching framework-neutral, so prefetch manifests no longer pull Vue runtime into the first page load.
- Added a narrow `live_islands/react/app` export for component registries that only need `createReactIsland`.
- Added `live-islands:hydrated` runtime events and benchmark FCP, LCP, hydrated island count, last-hydrated, and hydration-span measurements.
- Added runtime budgets, app-entry byte budgets, and release-to-release regression thresholds for both bytes and timings.
- Updated the benchmark release workflow to append the generated benchmark summary directly to GitHub Release notes.

## v0.4.2

Release benchmark history and environment metadata.

- Added benchmark environment fingerprints to JSON and Markdown results, including OS, CPU, Node, npm, Elixir, Erlang/OTP, Playwright, Chromium, package, command, and GitHub runner metadata.
- Updated the benchmark workflow so every `v*` release tag uploads stable benchmark assets to the GitHub Release.
- Added automatic comparison against the previous release benchmark asset when one is available.
- Documented the canonical CI benchmark environment and the local environment used to validate this benchmark stage.

## v0.4.1

Benchmark harness stability and route-flow measurement.

- Added multi-sample benchmark runs with min/median/max/mean stability stats for page load, byte totals, and heavy interaction timing.
- Added a `/capabilities` to `/benchmarks` LiveView navigation flow that verifies page-scoped manifests, lazy route chunks, and no premature PDF.js or KaTeX loading.
- Added route-flow byte budgets, one-sample smoke benchmarks, failed-response diagnostics, and a versioned benchmark result schema.

## v0.4.0

Production benchmarks and manifest-driven asset loading.

- Added a detailed `/benchmarks` example route that combines server-only SSR, React, Vue, page-scoped manifests, deferred hydration, KaTeX rendering, and PDF.js rendering.
- Added `npm run benchmarks`, budget checks, JSON/Markdown result output, browser error diagnostics, and comparison support for release-to-release measurement.
- Added a GitHub Actions benchmark workflow for `v*` release tags and manual runs.
- Switched production client builds to Vite content-hashed entrypoints and taught `LiveIslands.Reload.vite_assets` to render assets from the Vite manifest.
- Deferred hidden example code tabs with visible/hover strategies so they no longer hydrate or fetch code during the initial route load.

## v0.3.0

Route-scoped island loading and production manifest verification.

- Added page-scoped island manifest APIs with `getIslandScope`, `getIslandManifest({ scope: "page" })`, and `getPageIslandManifest`.
- Made the prefetch controller page-scoped by default, so LiveView navigation scans the current page boundary instead of the whole document.
- Enabled Vite build manifest output in the example and install templates.
- Extended the install verifier to check Vite manifest configuration and dynamic island chunk entries.
- Tightened E2E coverage for page-scoped manifests, server-only islands, LiveView interactions, SSR, and route navigation.

## v0.2.0

Astro-style loading and runtime ergonomics for page-aware islands.

- Added page-aware island prefetching with DOM manifests, lazy chunk preload support, and `getIslandManifest` / `setupIslandPrefetch` helpers.
- Added built-in `:interaction` hydration and prefetch strategies, plus `defineClientStrategy` and `definePrefetchStrategy` for application-defined scheduling.
- Added first-class server-only React and Vue islands with `<.react_server>` and `<.vue_server>`.
- Expanded installer guidance, integration checklists, verifier coverage, example coverage, and E2E tests for Vite, Tailwind, React, Vue, SSR, and lazy chunks.

## v0.1.0

Initial independent LiveIslands release with React and Vue component islands for Phoenix LiveView.

- Unified React and Vue adapters under one Elixir package and JavaScript package.
- Added Vite, Tailwind, SSR, lazy hydration, and install verification workflows.
- Added attribution for `mrdotb/live_react` and `Valian/live_vue`.
